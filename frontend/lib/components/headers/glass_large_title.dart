import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../buttons/glass_icon_button.dart';
import '../buttons/glass_surface.dart';

/// iOS 26 navigation header over a scrolling page:
///
/// - at rest: a row of glass buttons, and a large bold title under it on
///   the left that scrolls away with the content;
/// - scrolled: a small title fades in at the centre of the button row,
///   and the content fades out as it reaches the top edge (no bar, no
///   blur band, no line), as iOS 26's scroll edge effect does.
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
    final textTheme = Theme.of(context).textTheme;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          // iOS 26 scroll edge: content dissolves into the page as it nears
          // the top (an alpha fade), it isn't blurred behind a band. At
          // rest this strip is the empty space above the content, so the
          // mask only shows once something scrolls into it.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final h = bounds.height <= 0 ? 1.0 : bounds.height;
              final clear = (topPad + rowH * 0.45) / h;
              final solid = (topPad + rowH + 22) / h;
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xFF000000),
                ],
                stops: [0, clear.clamp(0.0, 1.0), solid.clamp(0.0, 1.0)],
              ).createShader(bounds);
            },
            child: widget.child,
          ),
          // Only the header repaints while scrolling.
          ValueListenableBuilder<double>(
            valueListenable: _offset,
            builder: (context, offset, _) {
              // 0 → resting, 1 → collapsed (large title gone).
              final t = ((offset - 16) / 32).clamp(0.0, 1.0);
              final largeTop = topPad + rowH - offset.clamp(-200.0, 200.0);
              return Stack(
                children: [
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
                    child: _HeaderCollapse(
                      progress: t,
                      child: Row(
                        children: [
                          if (widget.leading != null) widget.leading!,
                          const Spacer(),
                          if (widget.actions.isNotEmpty)
                            GlassActionGroup(children: widget.actions),
                        ],
                      ),
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

/// How collapsed the header is (0 resting → 1 collapsed), for
/// [HideOnCollapse] actions in the button row.
class _HeaderCollapse extends InheritedWidget {
  const _HeaderCollapse({required this.progress, required super.child});

  final double progress;

  @override
  bool updateShouldNotify(_HeaderCollapse old) => old.progress != progress;
}

/// A header action that only shows while the large title does: as the
/// header collapses it shrinks and fades away, making room for the small
/// centred title (e.g. the donate heart on Groups). Outside a
/// [GlassLargeTitleFrame] it's always shown.
class HideOnCollapse extends StatelessWidget {
  const HideOnCollapse({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t =
        context
            .dependOnInheritedWidgetOfExactType<_HeaderCollapse>()
            ?.progress ??
        0;
    if (t >= 1) return const SizedBox.shrink();
    final visible = 1 - Curves.easeOut.transform(t);
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: visible,
        child: Opacity(
          opacity: visible,
          child: IgnorePointer(ignoring: t > 0.5, child: child),
        ),
      ),
    );
  }
}
