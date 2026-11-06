import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';

/// Adds pointer affordance to any widget: hover feedback, a click cursor and
/// a keyboard focus ring.
///
/// Below [Breakpoints.shellWeb] this is a pass-through that only supplies the
/// tap target, so touch layouts behave exactly as they did before. Hover state
/// is never entered on a touch device anyway, but gating on the tier keeps the
/// mobile widget tree free of the extra [MouseRegion] and [Focus] nodes.
class Hoverable extends StatefulWidget {
  const Hoverable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 12,
    this.hoverElevation = true,
    this.hoverScale,
    this.semanticLabel,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Must match the radius of the child's own decoration so the hover overlay
  /// and focus ring line up with it.
  final double borderRadius;

  /// Lift the surface with a shadow on hover. Turn off for rows inside a list,
  /// where a background tint reads better than elevation.
  final bool hoverElevation;

  /// Optional scale on hover, e.g. 1.01. Left null by default — scaling text
  /// causes reflow shimmer, so only opt in for image-led cards.
  final double? hoverScale;

  final String? semanticLabel;
  final String? tooltip;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!context.widthTier.isWebTier) {
      return _wrapSemantics(
        widget.onTap == null
            ? widget.child
            : GestureDetector(onTap: widget.onTap, child: widget.child),
      );
    }

    final radius = BorderRadius.circular(widget.borderRadius);
    final active = _hovered || _focused;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: widget.hoverElevation && _hovered
            ? [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
        border: Border.all(
          color: _focused ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        color: _hovered
            ? theme.colorScheme.primary.withValues(alpha: 0.045)
            : Colors.transparent,
      ),
      child: ClipRRect(borderRadius: radius, child: widget.child),
    );

    if (widget.hoverScale != null) {
      content = AnimatedScale(
        scale: _hovered ? widget.hoverScale! : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: content,
      );
    }

    if (widget.tooltip != null) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }

    return _wrapSemantics(
      FocusableActionDetector(
        enabled: widget.onTap != null,
        mouseCursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onShowHoverHighlight: (v) {
          if (v != _hovered) setState(() => _hovered = v);
        },
        onShowFocusHighlight: (v) {
          if (v != _focused) setState(() => _focused = v);
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      ),
      isButton: active,
    );
  }

  Widget _wrapSemantics(Widget child, {bool isButton = false}) {
    if (widget.semanticLabel == null) return child;
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: child,
    );
  }
}

/// Row-shaped variant for lists: tints the background instead of lifting the
/// surface, which is the right feedback for a dense list of items.
class HoverableRow extends StatefulWidget {
  const HoverableRow({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 10,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final String? semanticLabel;

  @override
  State<HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<HoverableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!context.widthTier.isWebTier) {
      return widget.onTap == null
          ? widget.child
          : GestureDetector(onTap: widget.onTap, child: widget.child);
    }

    final theme = Theme.of(context);

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: _hovered
                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
