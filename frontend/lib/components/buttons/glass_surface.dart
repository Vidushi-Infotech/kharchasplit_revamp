import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// A tappable Liquid Glass surface (circle or pill) drawn by Flutter
/// (liquid_glass_renderer). Being part of the page, it appears instantly,
/// slides with page transitions and takes taps reliably — the native
/// UIKit glass inside Flutter pages popped in late and missed taps.
///
/// Pressing it squashes and stretches like iOS 26 glass.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.circle = true,
    this.tint,
    this.radius = 22,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// A circle (icon buttons) or a pill with [radius] (text buttons).
  final bool circle;

  /// Glass color; null = clear glass that adapts to light/dark.
  final Color? tint;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor =
        tint ??
        (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.55));
    final shape = circle
        ? const LiquidOval()
        : LiquidRoundedSuperellipse(borderRadius: radius);

    // Tinted (prominent) glass is mostly its color: a solid fill with a
    // light sheen and edge reads truer than refraction, which washes the
    // brand teal out to cyan.
    final Widget glass = tint != null
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(circle ? 999 : radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(Colors.white.withValues(alpha: 0.18), tint!),
                  tint!,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 0.8,
              ),
            ),
            child: child,
          )
        : LiquidGlass.withOwnLayer(
            settings: LiquidGlassSettings(
              thickness: 16,
              blur: 6,
              glassColor: glassColor,
              lightIntensity: 0.7,
              saturation: 1.4,
            ),
            shape: shape,
            child: child,
          );

    return DecoratedBox(
      // A soft shadow lifts clear glass off white pages, as on iOS 26.
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LiquidStretch(
        interactionScale: 1.06,
        stretch: 0.3,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: glass,
        ),
      ),
    );
  }
}
