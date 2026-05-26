import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/connectivity_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Slim top banner that appears when the device loses connectivity.
///
/// Mounted in `MaterialApp.builder` so it sits above every route — auth,
/// dashboard, modal sheets, etc. The banner uses [SafeArea] internally so
/// it sits below the status bar / notch, and pushes the underlying app
/// content down by its own height (no overlap).
///
/// On the offline → online transition it shows a one-shot "Back online"
/// snackbar, but only if the offline banner was actually visible during
/// this session (avoids a stray toast right after cold start).
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  /// True once we've shown the offline banner at least once this session.
  /// Gates the "Back online" snackbar — we don't pop a confirmation toast
  /// if the user never noticed they were offline in the first place.
  bool _hasBeenOffline = false;

  /// Used to find a ScaffoldMessenger for the recovery snackbar without
  /// touching the active route's BuildContext (which may have been
  /// disposed during a transition).
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offline = ref.watch(isOfflineProvider);

    if (offline && !_hasBeenOffline) {
      _hasBeenOffline = true;
    }

    // Listen for offline → online transitions and surface the snackbar.
    ref.listen<bool>(isOfflineProvider, (prev, next) {
      if (prev == true && next == false && _hasBeenOffline) {
        _showBackOnlineSnack(isDark);
      }
    });

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Column(
        children: [
          // The surface is height 0 when online — including no status-bar
          // padding — so the underlying Scaffold paints right up to the
          // notch as if the banner weren't here. Only when offline does
          // it expand to (statusBarHeight + bannerHeight) and tint the
          // status-bar area so the banner text reads against its own
          // background.
          _BannerSurface(isVisible: offline, isDark: isDark),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  void _showBackOnlineSnack(bool isDark) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'Back online',
              style: AppTextStyles.body2(isDark).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.tealDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Animated slide-and-collapse surface. Hidden = zero height (zero status-bar
/// inset too — looks like the widget isn't here). Visible = status-bar
/// inset + 32px tinted strip with the banner text. Status bar text reads
/// against the warning tint so the system clock / battery stay legible.
class _BannerSurface extends StatelessWidget {
  const _BannerSurface({required this.isVisible, required this.isDark});

  final bool isVisible;
  final bool isDark;

  static const _bannerHeight = 32.0;
  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final statusBarInset = MediaQuery.of(context).padding.top;
    final accent = AppColors.warning;
    final tintedBg = accent.withValues(alpha: isDark ? 0.22 : 0.16);

    return ClipRect(
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOut,
        // When hidden, total height is zero — no inset is reserved, so the
        // underlying Scaffold paints behind the status bar exactly as it
        // would without this widget.
        height: isVisible ? statusBarInset + _bannerHeight : 0,
        color: isVisible ? tintedBg : Colors.transparent,
        child: AnimatedOpacity(
          duration: _duration,
          opacity: isVisible ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.only(top: statusBarInset),
            child: _BannerContent(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.warning;
    return Container(
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: accent.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 13,
              color: accent,
            ),
            const SizedBox(width: 8),
            Text(
              'No internet connection',
              style: AppTextStyles.caption(isDark).copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
