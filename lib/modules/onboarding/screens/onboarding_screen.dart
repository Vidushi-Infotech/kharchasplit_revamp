import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive/responsive_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/buttons/primary_button.dart';
import '../state/onboarding_provider.dart';
import '../widgets/onboarding_slide_widget.dart';
import '../widgets/onboarding_dots_widget.dart';

/// Onboarding data structure
class OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;

  const OnboardingData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

/// Onboarding slides configuration
const List<OnboardingData> onboardingSlides = [
  OnboardingData(
    icon: Icons.group_rounded,
    title: 'Split with Anyone',
    subtitle: 'Add friends, create groups, and split expenses instantly — no awkward conversations.',
  ),
  OnboardingData(
    icon: Icons.receipt_long_rounded,
    title: 'Track Every Rupee',
    subtitle: 'Know exactly who owes what. Real-time balance updates across all your groups.',
  ),
  OnboardingData(
    icon: Icons.check_circle_rounded,
    title: 'Settle in Seconds',
    subtitle: 'One tap settlement with UPI, GPay, or cash. Clean history, zero confusion.',
  ),
];

/// Main onboarding screen with responsive layouts
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingPageProvider);
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isWeb = context.isWeb;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: RepaintBoundary(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () async {
                    await ref
                        .read(onboardingPageProvider.notifier)
                        .completeOnboarding();
                    if (mounted) {
                      context.go('/login');
                    }
                  },
                  child: Text(
                    'Skip Tour',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: isMobile
                  ? _buildMobileLayout(currentPage)
                  : isTablet
                      ? _buildTabletLayout(currentPage)
                      : _buildWebLayout(),
            ),
            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dots only on mobile/tablet
                  if (!isWeb)
                    OnboardingDotsWidget(
                      currentPage: currentPage,
                      totalPages: onboardingSlides.length,
                      onPageTapped: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  if (!isWeb) const SizedBox(height: 32),
                  // Navigation buttons
                  isWeb || currentPage == onboardingSlides.length - 1
                      ? SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: 'Get Started',
                            onPressed: () async {
                              await ref
                                  .read(onboardingPageProvider.notifier)
                                  .completeOnboarding();
                              if (mounted) {
                                context.go('/home');
                              }
                            },
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: 'Next',
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(int currentPage) {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) {
        ref.read(onboardingPageProvider.notifier).goToPage(index);
      },
      itemCount: onboardingSlides.length,
      itemBuilder: (context, index) => OnboardingSlideWidget(
        icon: onboardingSlides[index].icon,
        title: onboardingSlides[index].title,
        subtitle: onboardingSlides[index].subtitle,
      ),
    );
  }

  Widget _buildTabletLayout(int currentPage) {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) {
        ref.read(onboardingPageProvider.notifier).goToPage(index);
      },
      itemCount: onboardingSlides.length,
      itemBuilder: (context, index) => OnboardingSlideWidget(
        icon: onboardingSlides[index].icon,
        title: onboardingSlides[index].title,
        subtitle: onboardingSlides[index].subtitle,
        isTablet: true,
      ),
    );
  }

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Row(
              children: List.generate(
                onboardingSlides.length,
                (index) => Expanded(
                  child: OnboardingSlideWidget(
                    icon: onboardingSlides[index].icon,
                    title: onboardingSlides[index].title,
                    subtitle: onboardingSlides[index].subtitle,
                    isWeb: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
