import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive_utils.dart';
import '../../../core/constants/onboarding_constants.dart';
import 'onboarding_provider.dart';
import 'widgets/onboarding_page_widget.dart';
import 'widgets/onboarding_dots_indicator.dart';

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
    final isWeb = context.isWeb;
    final isTablet = context.isTablet;
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RepaintBoundary(
        child: isMobile
            ? _buildMobileLayout(context, currentPage, isWeb, isTablet)
            : isTablet
                ? _buildTabletLayout(context, currentPage, isWeb, isTablet)
                : _buildWebLayout(context, isWeb, isTablet),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    int currentPage,
    bool isWeb,
    bool isTablet,
  ) {
    return Column(
      children: [
        // Skip button (top-right)
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => ref.read(onboardingPageProvider.notifier).skipOnboarding(),
              child: const Text('Skip Tour'),
            ),
          ),
        ),
        // PageView (full height)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              ref.read(onboardingPageProvider.notifier).goToPage(index);
            },
            itemCount: onboardingPages.length,
            itemBuilder: (context, index) => OnboardingPageWidget(
              pageData: onboardingPages[index],
              isWeb: isWeb,
              isTablet: isTablet,
            ),
          ),
        ),
        // Dots and bottom navigation
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              OnboardingDotsIndicator(
                currentPage: currentPage,
                onPageSelected: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    int currentPage,
    bool isWeb,
    bool isTablet,
  ) {
    return Column(
      children: [
        // Skip button (top-right)
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => ref.read(onboardingPageProvider.notifier).skipOnboarding(),
              child: const Text('Skip Tour'),
            ),
          ),
        ),
        // Two-slide view with PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              ref.read(onboardingPageProvider.notifier).goToPage(index);
            },
            itemCount: onboardingPages.length,
            itemBuilder: (context, index) => OnboardingPageWidget(
              pageData: onboardingPages[index],
              isWeb: isWeb,
              isTablet: isTablet,
            ),
          ),
        ),
        // Dots
        Padding(
          padding: const EdgeInsets.all(24),
          child: OnboardingDotsIndicator(
            currentPage: currentPage,
            onPageSelected: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWebLayout(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    return Column(
      children: [
        // Skip button (top-right)
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => ref.read(onboardingPageProvider.notifier).skipOnboarding(),
              child: const Text('Skip Tour'),
            ),
          ),
        ),
        // All 3 slides in a row
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: List.generate(
                      onboardingPages.length,
                      (index) => SizedBox(
                        width: 350,
                        child: OnboardingPageWidget(
                          pageData: onboardingPages[index],
                          isWeb: isWeb,
                          isTablet: isTablet,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Dots (non-interactive on web)
        Padding(
          padding: const EdgeInsets.all(24),
          child: OnboardingDotsIndicator(
            currentPage: -1,
            onPageSelected: (_) {},
          ),
        ),
      ],
    );
  }
}
