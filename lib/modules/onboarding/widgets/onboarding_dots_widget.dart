import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Animated dot indicator for onboarding slides
/// Active dot expands and changes color
class OnboardingDotsWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageTapped;

  const OnboardingDotsWidget({
    Key? key,
    required this.currentPage,
    this.totalPages = 3,
    required this.onPageTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalPages,
          (index) => GestureDetector(
            onTap: () => onPageTapped(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              height: 8,
              width: currentPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? AppColors.tealDark
                    : AppColors.divider(isDark),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
