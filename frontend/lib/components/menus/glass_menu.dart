import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';

/// One row of a [showGlassMenu].
class GlassMenuItem<T> {
  const GlassMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.checked = false,
    this.destructive = false,
    this.dividerBefore = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Shows a check mark (the current choice in a picker-style menu).
  final bool checked;

  /// Red, for actions like Delete.
  final bool destructive;

  /// A hairline above this row, to group related actions.
  final bool dividerBefore;
}

/// iOS 26 style pull-down menu: a Liquid Glass panel that grows out of
/// [anchorContext]'s widget with a spring and shrinks back into it when
/// dismissed. Resolves to the picked value, or null when tapped outside.
Future<T?> showGlassMenu<T>(
  BuildContext anchorContext,
  List<GlassMenuItem<T>> items,
) {
  final anchorBox = anchorContext.findRenderObject()! as RenderBox;
  final navigator = Navigator.of(anchorContext, rootNavigator: true);
  final overlayBox =
      navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor = Rect.fromPoints(
    anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox),
    anchorBox.localToGlobal(
      anchorBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    ),
  );
  return navigator.push<T>(
    _GlassMenuRoute<T>(
      anchor: anchor,
      items: items,
      barrierLabel: MaterialLocalizations.of(
        anchorContext,
      ).modalBarrierDismissLabel,
    ),
  );
}

class _GlassMenuRoute<T> extends PopupRoute<T> {
  _GlassMenuRoute({
    required this.anchor,
    required this.items,
    required this.barrierLabel,
  });

  final Rect anchor;
  final List<GlassMenuItem<T>> items;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _GlassMenuLayout<T>(
      anchor: anchor,
      items: items,
      animation: animation,
    );
  }
}

class _GlassMenuLayout<T> extends StatelessWidget {
  const _GlassMenuLayout({
    required this.anchor,
    required this.items,
    required this.animation,
  });

  final Rect anchor;
  final List<GlassMenuItem<T>> items;
  final Animation<double> animation;

  static const double _width = 250;
  static const double _rowHeight = 46;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final dividers = items.where((i) => i.dividerBefore).length;
    final height = items.length * _rowHeight + dividers * 1.0 + 12;

    // Open under the button, or above it when there's no room below.
    final below = anchor.bottom + _gap + height < size.height - pad.bottom - 8;
    final top = below
        ? anchor.bottom + _gap
        : (anchor.top - _gap - height).clamp(pad.top + 8, size.height);
    // Hug the button's side of the screen.
    final rightSide = anchor.center.dx > size.width / 2;
    final left = rightSide
        ? (anchor.right - _width).clamp(12.0, size.width - _width - 12)
        : anchor.left.clamp(12.0, size.width - _width - 12);

    // The panel grows out of the button.
    final origin = Alignment(
      ((anchor.center.dx - left) / _width) * 2 - 1,
      below ? -1 : 1,
    );
    final grow = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    return Stack(
      children: [
        Positioned(
          top: top.toDouble(),
          left: left.toDouble(),
          width: _width,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween(begin: 0.4, end: 1.0).animate(grow),
              alignment: origin,
              child: _GlassMenuPanel<T>(items: items),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassMenuPanel<T> extends StatelessWidget {
  const _GlassMenuPanel({required this.items});

  final List<GlassMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final anyChecked = items.any((i) => i.checked);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                  .withValues(alpha: isDark ? 0.72 : 0.78),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.08,
                ),
                width: 0.6,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in items) ...[
                      if (item.dividerBefore)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.divider(isDark),
                        ),
                      _GlassMenuRow<T>(item: item, showCheckSlot: anyChecked),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMenuRow<T> extends StatelessWidget {
  const _GlassMenuRow({required this.item, required this.showCheckSlot});

  final GlassMenuItem<T> item;
  final bool showCheckSlot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = item.destructive
        ? AppColors.errorText(isDark)
        : AppColors.textPrimary(isDark);
    return Semantics(
      button: true,
      selected: item.checked,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticService.instance.selection();
          Navigator.of(context).pop(item.value);
        },
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: _GlassMenuLayout._rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (showCheckSlot)
                  SizedBox(
                    width: 26,
                    child: item.checked
                        ? Icon(Icons.check_rounded, size: 18, color: color)
                        : null,
                  ),
                if (item.icon != null) ...[
                  Icon(item.icon, size: 20, color: color),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: item.checked
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
