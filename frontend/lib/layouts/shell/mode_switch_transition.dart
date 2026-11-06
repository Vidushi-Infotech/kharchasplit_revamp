import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/state/app_mode.dart';
import '../../core/theme/app_colors.dart';

/// The page holding a mode's shell (Groups or Personal).
///
/// Switching modes opens the new one in a circle that grows from the
/// switch the user tapped, over the old one (which stays still behind it),
/// with the new mode's name in the middle for a moment: it reads as
/// changing apps, not as pushing a page. Any other arrival (app launch,
/// sign-in) just fades in. Tabs inside a shell keep its key, so moving
/// between them doesn't animate this.
Page<void> modeShellPage({
  required String key,
  required AppMode mode,
  required Widget child,
}) {
  if (ModeSwitchSignal.take(mode)) _ModeReveal.revealing = key;
  return CustomTransitionPage<void>(
    key: ValueKey(key),
    child: child,
    transitionDuration: _ModeReveal.duration,
    // The outgoing shell stays on screen while the new one opens over it.
    reverseTransitionDuration: _ModeReveal.duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (animation.status == AnimationStatus.reverse) return child;
      final reveal =
          _ModeReveal.revealing == key &&
          !MediaQuery.disableAnimationsOf(context);
      if (!reveal) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.6, curve: Curves.easeOut),
          ),
          child: child,
        );
      }
      return _ModeReveal(
        animation: animation,
        mode: mode,
        pageKey: key,
        child: child,
      );
    },
  );
}

class _ModeReveal extends StatefulWidget {
  const _ModeReveal({
    required this.animation,
    required this.mode,
    required this.pageKey,
    required this.child,
  });

  static const duration = Duration(milliseconds: 620);

  /// The shell page being revealed right now (one switch at a time).
  static String? revealing;

  final Animation<double> animation;
  final AppMode mode;
  final String pageKey;
  final Widget child;

  @override
  State<_ModeReveal> createState() => _ModeRevealState();

  /// In over the first third, held, out over the last third.
  static double _badgeOpacity(double v) {
    if (v < 0.05) return 0;
    if (v < 0.3) return (v - 0.05) / 0.25;
    if (v < 0.68) return 1;
    return (1 - (v - 0.68) / 0.32).clamp(0.0, 1.0);
  }

  static double _farthestCorner(Offset o, Size s) => [
    Offset.zero,
    Offset(s.width, 0),
    Offset(0, s.height),
    Offset(s.width, s.height),
  ].map((corner) => (corner - o).distance).reduce(math.max);
}

class _ModeRevealState extends State<_ModeReveal> {
  /// Whether the opening animation has started. Until then the new mode
  /// stays hidden, so it can't flash in full for a frame first.
  bool _started = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
    // Never leave it hidden if, somehow, the animation doesn't run.
    _fallback = Timer(_ModeReveal.duration * 2, () {
      if (mounted && !_started) setState(() => _started = true);
    });
  }

  @override
  void dispose() {
    _fallback?.cancel();
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  /// The page is built once before its animation starts (already
  /// "completed"); only the end of the real run ends the reveal.
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward && !_started) {
      setState(() => _started = true);
    }
    if (status == AnimationStatus.completed &&
        _ModeReveal.revealing == widget.pageKey) {
      _ModeReveal.revealing = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, child) {
        final v = widget.animation.value;
        if (!_started) return const SizedBox.shrink();
        if (widget.animation.isCompleted) return child!;
        // Opens at once under the finger, then settles.
        final grow = Curves.fastOutSlowIn.transform(v);
        return LayoutBuilder(
          builder: (context, c) {
            final size = c.biggest;
            // Where the switch was tapped; else the bar's last item.
            final origin =
                ModeSwitchSignal.origin ??
                Offset(size.width - 44, size.height - 56);
            final radius = _ModeReveal._farthestCorner(origin, size) * grow;
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipPath(clipper: _CircleClipper(origin, radius), child: child),
                IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: _ModeReveal._badgeOpacity(v),
                      child: Transform.scale(
                        scale:
                            0.85 +
                            0.15 *
                                Curves.easeOutBack.transform(
                                  (v / 0.4).clamp(0.0, 1.0),
                                ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: _ModeBadge(mode: widget.mode),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.center != center || old.radius != radius;
}

/// "Personal" / "Groups" in a brand pill, shown while the mode opens.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    final personal = mode == AppMode.personal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            personal
                ? Icons.account_balance_wallet_rounded
                : Icons.groups_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 10),
          Text(
            personal ? AppStrings.personal : AppStrings.groups,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
