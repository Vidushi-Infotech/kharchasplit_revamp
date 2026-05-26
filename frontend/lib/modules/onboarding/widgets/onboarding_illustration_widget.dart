import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Circular gradient container with centered icon illustration
/// Wrapped in RepaintBoundary for 90Hz+ performance
class OnboardingIllustrationWidget extends StatelessWidget {
  final IconData icon;
  final double size;

  const OnboardingIllustrationWidget({
    Key? key,
    required this.icon,
    this.size = 100,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.tealDark,
              AppColors.greenLight,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealDark.withValues(alpha: isDark ? 0.4 : 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
