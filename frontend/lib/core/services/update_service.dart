import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_version/app_version_repository.dart';
import 'app_logger.dart';

/// Decision the service produces after comparing current → server config.
enum UpdateAction { none, soft, force }

/// Coordinates in-app update prompts across platforms.
///
/// - Android: uses Google Play in-app update API (flexible for soft, immediate
///   for force). The Play Store UI is the prompt; we just kick it off.
/// - iOS: no native equivalent. We show a Cupertino dialog (dismissible for
///   soft, blocking for force) and route the user to the App Store.
///
/// Soft updates are throttled to once every 24h so we don't nag.
/// Force updates ignore the throttle.
class UpdateService {
  UpdateService(this._ref);
  final Ref _ref;

  /// SharedPreferences key holding the last soft-prompt timestamp (ms epoch).
  static const _kLastSoftCheckMs = 'update_last_soft_check_ms';
  static const _softCheckCooldown = Duration(hours: 24);

  /// Public entry point — call once after the app's first frame.
  ///
  /// Pass the navigator key from go_router (`appRouter.routerDelegate.navigatorKey`)
  /// so we can show dialogs without needing a BuildContext from the caller.
  Future<void> checkForUpdate({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    try {
      final repo = _ref.read(appVersionRepositoryProvider);
      final config = await repo.fetch();
      if (config == null) {
        AppLogger.info('Update check: server config unavailable — skipping',
            tag: 'UpdateService');
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "3.3.0"

      final action = _decideAction(
        current: current,
        latest: config.latestVersion,
        minSupported: config.minSupportedVersion,
      );

      AppLogger.info(
        'Update check: current=$current latest=${config.latestVersion} '
        'min=${config.minSupportedVersion} → action=$action',
        tag: 'UpdateService',
      );

      switch (action) {
        case UpdateAction.none:
          return;
        case UpdateAction.soft:
          if (!await _shouldShowSoft()) return;
          await _markSoftShown();
          await _handleSoftUpdate(navigatorKey, config);
          return;
        case UpdateAction.force:
          await _handleForceUpdate(navigatorKey, config);
          return;
      }
    } catch (e, st) {
      AppLogger.error('Update check failed',
          tag: 'UpdateService', error: e, stackTrace: st);
    }
  }

  // ----------------- decision -----------------

  /// Compare semantic versions. Returns:
  ///   force when `current < minSupported`
  ///   soft  when `current < latest`
  ///   none  otherwise
  UpdateAction _decideAction({
    required String current,
    required String latest,
    required String minSupported,
  }) {
    if (_compare(current, minSupported) < 0) return UpdateAction.force;
    if (_compare(current, latest) < 0) return UpdateAction.soft;
    return UpdateAction.none;
  }

  /// Returns -1 if `a < b`, 0 if equal, 1 if `a > b`. Strips '+buildcode' suffix.
  /// Pads missing parts with 0, so "3.3" == "3.3.0".
  int _compare(String a, String b) {
    final aParts = _parseSegments(a);
    final bParts = _parseSegments(b);
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av < bv ? -1 : 1;
    }
    return 0;
  }

  List<int> _parseSegments(String v) {
    final stripped = v.split('+').first.trim();
    return stripped
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList(growable: false);
  }

  // ----------------- throttle -----------------

  Future<bool> _shouldShowSoft() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastSoftCheckMs);
    if (last == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= _softCheckCooldown.inMilliseconds;
  }

  Future<void> _markSoftShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _kLastSoftCheckMs, DateTime.now().millisecondsSinceEpoch);
  }

  // ----------------- soft update -----------------

  Future<void> _handleSoftUpdate(
    GlobalKey<NavigatorState> navigatorKey,
    AppVersionConfig config,
  ) async {
    if (Platform.isAndroid) {
      // Try Play's flexible flow — Play renders its own UI.
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            await InAppUpdate.completeFlexibleUpdate();
          }
          return;
        }
      } catch (e) {
        // Play Core may be unavailable on emulators / sideloaded builds.
        // Fall through to the custom dialog so we still nudge the user.
        AppLogger.warn('Play in-app update unavailable: $e',
            tag: 'UpdateService');
      }
    }
    // iOS path (and Android fallback) — show our own dismissible dialog.
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await _showCustomDialog(ctx, config, blocking: false);
  }

  // ----------------- force update -----------------

  Future<void> _handleForceUpdate(
    GlobalKey<NavigatorState> navigatorKey,
    AppVersionConfig config,
  ) async {
    if (Platform.isAndroid) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          // Immediate flow — Play renders a full-screen blocking page.
          await InAppUpdate.performImmediateUpdate();
          return;
        }
      } catch (e) {
        AppLogger.warn('Play immediate update unavailable: $e',
            tag: 'UpdateService');
      }
    }
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await _showCustomDialog(ctx, config, blocking: true);
  }

  // ----------------- custom dialog (iOS + Android fallback) -----------------

  Future<void> _showCustomDialog(
    BuildContext context,
    AppVersionConfig config, {
    required bool blocking,
  }) async {
    final storeUrl =
        Platform.isIOS ? config.iosStoreUrl : config.androidStoreUrl;
    final title = blocking ? 'Update required' : 'Update available';
    final message =
        blocking ? config.forceUpdateMessage : config.softUpdateMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: !blocking,
      builder: (dialogContext) => PopScope(
        canPop: !blocking,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (!blocking)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                await _openStore(storeUrl);
                // Soft: dismiss after launching the store so the user lands
                // back in the app smoothly. Force: keep the dialog up — the
                // next checkForUpdate cycle will reopen it anyway.
                if (!blocking && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('Failed to open store URL', tag: 'UpdateService', error: e);
    }
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(ref);
});
