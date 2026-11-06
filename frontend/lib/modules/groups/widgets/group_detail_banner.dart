import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/group_model.dart';
import 'group_cover_thumb.dart';

/// Banner across the top of group detail: the group's cover photo when it
/// has one, otherwise a teal gradient with a soft circle pattern. Purely
/// decorative — the group name is announced by the header below.
class GroupBannerArt extends StatelessWidget {
  const GroupBannerArt({super.key, required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Direct groups have no cover of their own — always the pattern.
    final bytes = group.isDirect
        ? null
        : decodeGroupCover(group.coverImageBase64);
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _PatternBanner(isDark: isDark),
            )
          else
            _PatternBanner(isDark: isDark),
          // Top scrim keeps the white back / settings icons readable on
          // any photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x55000000), Color(0x00000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternBanner extends StatelessWidget {
  const _PatternBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [AppColors.darkCardBg, AppColors.tealDark]
              : const [AppColors.tealDark, AppColors.tealLight],
        ),
      ),
      child: const RepaintBoundary(
        child: CustomPaint(painter: _CirclePatternPainter()),
      ),
    );
  }
}

/// Overlapping outline circles in the brand's own style — a quiet texture
/// rather than an illustration.
class _CirclePatternPainter extends CustomPainter {
  const _CirclePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.10);
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final step = math.max(56.0, size.width / 7);
    var row = 0;
    for (var y = -step / 2; y < size.height + step; y += step * 0.8) {
      final offset = row.isEven ? 0.0 : step / 2;
      for (var x = -step + offset; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x, y), step * 0.42, stroke);
      }
      row++;
    }
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      size.height * 0.55,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Square group avatar that overlaps the banner's bottom edge: the cover
/// photo / emoji, or the friend's avatar for a direct group.
class GroupBannerAvatar extends StatelessWidget {
  const GroupBannerAvatar({super.key, required this.child, this.size = 64});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background(isDark),
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: ColoredBox(color: AppColors.inputFill(isDark), child: child),
      ),
    );
  }
}
