import 'package:flutter/material.dart';
import '../../../../core/constants/onboarding_constants.dart';

class OnboardingDotsIndicator extends StatelessWidget {
  final int currentPage;
  final Function(int) onPageSelected;

  const OnboardingDotsIndicator({
    Key? key,
    required this.currentPage,
    required this.onPageSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          onboardingPages.length,
          (index) => GestureDetector(
            onTap: () => onPageSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              height: 8,
              width: currentPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
