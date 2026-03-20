import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'onboarding_illustration_widget.dart';

/// Single onboarding slide with illustration, title, and subtitle
class OnboardingSlideWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isWeb;
  final bool isTablet;

  const OnboardingSlideWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isWeb = false,
    this.isTablet = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final illustrationSize = (isWeb ? 140 : isTablet ? 120 : 100).toDouble();
    final titleFontSize = isWeb ? 28.0 : isTablet ? 24.0 : 22.0;
    final subtitleFontSize = isWeb ? 16.0 : isTablet ? 15.0 : 14.0;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 40 : isTablet ? 24 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            OnboardingIllustrationWidget(
              icon: icon,
              size: illustrationSize,
            ),
            SizedBox(height: isWeb ? 40 : 32),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline2(isDark).copyWith(
                fontSize: titleFontSize,
              ),
            ),
            SizedBox(height: isWeb ? 16 : 12),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(isDark).copyWith(
                fontSize: subtitleFontSize,
                color: AppColors.textSecondary(isDark),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
