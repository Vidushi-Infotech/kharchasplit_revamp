import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Dashboard background: a subtle teal dot grid that fades toward the
/// bottom of the screen, layered behind one soft radial glow under the
/// hero header. Inspired by 21st.dev's dot-grid backgrounds.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dot grid covers the entire background.
            Positioned.fill(
              child: CustomPaint(
                painter: _DotGridPainter(isDark: isDark),
              ),
            ),
            // Soft teal glow under the hero header (top area).
            Positioned(
              top: -120,
              right: -100,
              child: _Glow(
                size: 380,
                color: AppColors.tealLight,
                alpha: isDark ? 0.28 : 0.18,
              ),
            ),
            // Subtle secondary glow on the opposite side for depth.
            Positioned(
              top: 60,
              left: -120,
              child: _Glow(
                size: 280,
                color: AppColors.greenLight,
                alpha: isDark ? 0.16 : 0.10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.isDark});

  final bool isDark;

  /// Spacing between dot centers, in logical pixels.
  static const double _spacing = 22;

  /// Dot radius.
  static const double _dotRadius = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark
        ? AppColors.tealLight
        : AppColors.tealDark;
    final paint = Paint()..style = PaintingStyle.fill;

    // Vertical opacity falloff: dots are most visible near the top and
    // dissolve toward the bottom so the lower content cards stay clean.
    for (double y = _spacing; y < size.height; y += _spacing) {
      final progress = (y / size.height).clamp(0.0, 1.0);
      // Strong at top → near 0 at 70% down the screen.
      final falloff = (1 - (progress / 0.7)).clamp(0.0, 1.0);
      final alpha = (isDark ? 0.18 : 0.14) * falloff;
      if (alpha < 0.005) continue;
      paint.color = baseColor.withValues(alpha: alpha);
      for (double x = _spacing; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), _dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
