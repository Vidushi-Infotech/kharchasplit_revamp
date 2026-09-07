import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/auth/state/auth_provider.dart';
import '../../modules/dashboard/state/dashboard_provider.dart';
import '../../modules/notifications/state/notifications_inbox_provider.dart';
import '../routing/app_router.dart';
import '../services/update_service.dart';
import '../state/connectivity_provider.dart';

/// Refreshes the app's core data when it comes back to the foreground after
/// being backgrounded for a while.
///
/// Before this existed nothing reacted to resume at all: a user who left the
/// app in Recents for an hour came back to hour-old balances until they
/// pulled to refresh, and the force-update gate was only evaluated once per
/// process. This is the Flutter equivalent of Android's `onResume` handling.
///
/// Wrap the signed-in shell with it. The refreshes below keep the current
/// data on screen while fetching (see the providers' `refresh()`), so a
/// resume never drops the UI to a skeleton.
class AppLifecycleRefresher extends ConsumerStatefulWidget {
  const AppLifecycleRefresher({super.key, required this.child});

  final Widget child;

  /// Below this the app was probably just covered by a permission dialog,
  /// share sheet or a quick app switch — nothing worth refetching for.
  static const Duration staleAfter = Duration(minutes: 2);

  @override
  ConsumerState<AppLifecycleRefresher> createState() =>
      _AppLifecycleRefresherState();
}

class _AppLifecycleRefresherState extends ConsumerState<AppLifecycleRefresher>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // `inactive` is deliberately ignored — it fires for transient
        // overlays (notification shade, permission dialogs) too.
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) return;
        if (DateTime.now().difference(since) <
            AppLifecycleRefresher.staleAfter) {
          return;
        }
        _onResumedAfterLongBackground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onResumedAfterLongBackground() {
    // Connectivity may have changed while we weren't listening closely;
    // make the banner state self-correct without waiting for an OS event.
    unawaited(ref.read(connectivityServiceProvider).recheck());

    if (ref.read(authProvider).user == null) return;

    // Dashboard refresh also refreshes the groups list underneath it.
    unawaited(ref.read(dashboardProvider.notifier).refresh());
    unawaited(ref.read(notificationsInboxProvider.notifier).refresh());

    // Re-evaluate the version gate; the service throttles soft prompts to
    // once a day, so this is cheap when nothing changed.
    unawaited(
      ref
          .read(updateServiceProvider)
          .checkForUpdate(navigatorKey: appRouter.routerDelegate.navigatorKey),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
