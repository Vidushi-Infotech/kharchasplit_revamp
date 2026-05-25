import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Slim animated progress bar + "N of M" caption for the onboarding tour.
///
/// Visual: a thin pill-shaped track with a teal fill that animates to the
/// percentage of slides completed. Replaces the older dots indicator —
/// fits the modern, restrained onboarding style.
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
    // Force-dark palette — the tour is dark regardless of system theme.
    const trackBg = Color(0x1FFFFFFF); // white 12%
    const muted = Color(0xFF8A93A0);

    // Map "page N" to a fill fraction. We treat the first page as ~33% so
    // the bar never starts empty — it always shows progress.
    final fraction = ((currentPage + 1) / totalPages).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${currentPage + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                ' of $totalPages',
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${(fraction * 100).round()}%',
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Slim animated track. Tappable segments are kept for parity with
          // the old dots widget — tapping the rough position of a future
          // slide jumps to it.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    // Track
                    Container(
                      decoration: BoxDecoration(
                        color: trackBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // Fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      width: width * fraction,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.tealDark,
                            AppColors.greenLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.tealDark.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: -2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    // Tap targets — invisible Row over the track for jumps.
                    Row(
                      children: List.generate(totalPages, (i) {
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => onPageTapped(i),
                            child: const SizedBox.expand(),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
