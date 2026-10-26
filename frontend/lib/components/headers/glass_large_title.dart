import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../buttons/glass_icon_button.dart';
import '../buttons/glass_surface.dart';

/// iOS 26 navigation header over a scrolling page:
///
/// - at rest: a row of glass buttons, and a large bold title under it on
///   the left that scrolls away with the content;
/// - scrolled: a small title fades in at the centre of the button row,
///   and a soft scroll-edge effect (blur + fade, no bar, no line) keeps
///   the buttons readable over the content.
///
/// The page's scroll view must start with [topInset] of empty space (the
/// header is drawn over it). Used on iOS 26+ only; elsewhere screens keep
/// their own app bars.
class GlassLargeTitleFrame extends StatefulWidget {
  const GlassLargeTitleFrame({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final Widget child;

  /// Usually a [GlassBackButton] on pushed pages; null on tab roots.
  final Widget? leading;

  /// Header actions; adjacent ones share one glass capsule (see
  /// [GlassActionGroup]).
  final List<Widget> actions;

  static const double _rowHeight = 52;
  static const double _largeTitleHeight = 52;

  /// Space the page's scroll view must leave at its top.
  static double topInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + _rowHeight + _largeTitleHeight;

  @override
  State<GlassLargeTitleFrame> createState() => _GlassLargeTitleFrameState();
}

class _GlassLargeTitleFrameState extends State<GlassLargeTitleFrame> {
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      _offset.value = n.metrics.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.paddingOf(context).top;
    const rowH = GlassLargeTitleFrame._rowHeight;
    final bg = AppColors.background(isDark);
    final textTheme = Theme.of(context).textTheme;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          // Only the header repaints while scrolling.
          ValueListenableBuilder<double>(
            valueListenable: _offset,
            builder: (context, offset, _) {
              // 0 → resting, 1 → collapsed (large title gone).
              final t = ((offset - 16) / 32).clamp(0.0, 1.0);
              final largeTop = topPad + rowH - offset.clamp(-200.0, 200.0);
              return Stack(
                children: [
                  // Soft scroll-edge effect: blur that fades out downward.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topPad + rowH + 18,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: t,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    bg.withValues(alpha: 0.92),
                                    bg.withValues(alpha: 0.7),
                                    bg.withValues(alpha: 0),
                                  ],
                                  stops: const [0, 0.65, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Large title, moving with the content.
                  if (offset < GlassLargeTitleFrame._largeTitleHeight + 8)
                    Positioned(
                      top: largeTop,
                      left: 16,
                      right: 16,
                      height: GlassLargeTitleFrame._largeTitleHeight,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Semantics(
                            header: true,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: AppColors.textPrimary(isDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Small title, centred on the whole width like iOS
                  // (not between unequal leading/trailing widths).
                  Positioned(
                    top: topPad,
                    left: 112,
                    right: 112,
                    height: rowH,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: t,
                        child: Center(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Button row.
                  Positioned(
                    top: topPad,
                    left: 12,
                    right: 12,
                    height: rowH,
                    child: Row(
                      children: [
                        if (widget.leading != null) widget.leading!,
                        const Spacer(),
                        if (widget.actions.isNotEmpty)
                          GlassActionGroup(children: widget.actions),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Adjacent header actions sharing one glass capsule, as iOS 26 groups
/// toolbar items. Pass [GlassIconButton]s; they're drawn flat inside the
/// capsule ([GlassIconButton.inCapsule]).
class GlassActionGroup extends StatelessWidget {
  const GlassActionGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.length == 1) return children.first;
    return SizedBox(
      height: GlassIconButton.size,
      child: GlassSurface(
        circle: false,
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: GlassCapsuleScope(
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// Tells [GlassIconButton]s they sit inside a [GlassActionGroup] capsule,
/// so they draw just the icon (no circle of their own).
class GlassCapsuleScope extends InheritedWidget {
  const GlassCapsuleScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassCapsuleScope>() != null;

  @override
  bool updateShouldNotify(GlassCapsuleScope oldWidget) => false;
}
