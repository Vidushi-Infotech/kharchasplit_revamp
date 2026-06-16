import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../state/onboarding_provider.dart';
import '../widgets/onboarding_dots_widget.dart';
import '../widgets/onboarding_preview_widgets.dart';
import '../widgets/onboarding_slide_widget.dart';

/// Per-slide content + preview widget builder. Kept here (not in a
/// constants file) because each slide is paired tightly with the widget
/// that renders its hero mockup.
class _OnboardingSlide {
  final Widget Function() previewBuilder;
  final String headline;
  final String body;
  final Color accent;

  const _OnboardingSlide({
    required this.previewBuilder,
    required this.headline,
    required this.body,
    required this.accent,
  });
}

final List<_OnboardingSlide> _slides = [
  _OnboardingSlide(
    previewBuilder: () => const InvitePreview(),
    headline: 'Invite anyone',
    body:
        'Pull friends straight from your contacts. We email the ones not on KharchaSplit yet.',
    accent: AppColors.tealDark,
  ),
  _OnboardingSlide(
    previewBuilder: () => const SplitPreview(),
    headline: 'Split your way',
    body:
        'Equally, unequally, by % or shares. Scan a bill and the amount fills itself.',
    accent: const Color(0xFF6C8AE6),
  ),
  _OnboardingSlide(
    previewBuilder: () => const SettlePreview(),
    headline: 'Settle without doubt',
    body:
        'See exactly who you owe. Tap Settle — both sides confirm. Pair history stays clean.',
    accent: AppColors.greenLight,
  ),
];

const Color _bgTop = Color(0xFF0A0E14);
const Color _bgBottom = Color(0xFF050709);

/// Modern, dark, component-forward onboarding tour.
/// 21st.dev-inspired: bold display headlines, restrained motion, and a
/// hero "feature preview" card built from real-looking app components
/// (rather than a generic icon illustration).
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

  Future<void> _finishTour() async {
    await ref.read(onboardingPageProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/login');
  }

  void _goToNext() {
    final cur = ref.read(onboardingPageProvider);
    if (cur >= _slides.length - 1) {
      _finishTour();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingPageProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;
    final isWeb = screenWidth >= 1100;
    final accent = _slides[currentPage].accent;

    return Scaffold(
      backgroundColor: _bgTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Base gradient backdrop
            const _BaseBackdrop(),
            // Soft accent glow that shifts color with the active slide.
            _AccentGlow(color: accent),
            // Sparse dot grid for texture (very subtle)
            const _DotGridOverlay(),
            // Foreground content
            SafeArea(
              child: Column(
                children: [
                  // Top row: brand mark left, skip right
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                    child: Row(
                      children: [
                        const _BrandMark(),
                        const Spacer(),
                        _SkipButton(onTap: _finishTour),
                      ],
                    ),
                  ),
                  // Slides
                  Expanded(
                    child: isWeb
                        ? _buildWebLayout()
                        : PageView.builder(
                            controller: _pageController,
                            physics: const BouncingScrollPhysics(),
                            onPageChanged: (i) => ref
                                .read(onboardingPageProvider.notifier)
                                .goToPage(i),
                            itemCount: _slides.length,
                            itemBuilder: (context, index) {
                              final s = _slides[index];
                              return AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 320),
                                switchInCurve: Curves.easeOutCubic,
                                transitionBuilder: (child, anim) {
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.04),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey('slide-$index'),
                                  child: OnboardingSlideWidget(
                                    preview: s.previewBuilder(),
                                    headline: s.headline,
                                    body: s.body,
                                    isTablet: isTablet,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Bottom controls — progress bar + CTA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isWeb)
                          OnboardingDotsWidget(
                            currentPage: currentPage,
                            totalPages: _slides.length,
                            onPageTapped: (i) {
                              _pageController.animateToPage(
                                i,
                                duration:
                                    const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              );
                            },
                          ),
                        const SizedBox(height: 18),
                        _PrimaryCta(
                          label: (isWeb || currentPage == _slides.length - 1)
                              ? 'Get Started'
                              : 'Next',
                          onTap: (isWeb ||
                                  currentPage == _slides.length - 1)
                              ? _finishTour
                              : _goToNext,
                          accent: accent,
                        ),
                      ],
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

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Row(
              children: List.generate(_slides.length, (index) {
                final s = _slides[index];
                return Expanded(
                  child: OnboardingSlideWidget(
                    preview: s.previewBuilder(),
                    headline: s.headline,
                    body: s.body,
                    isWeb: true,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Backdrop layers
// --------------------------------------------------------------------------

class _BaseBackdrop extends StatelessWidget {
  const _BaseBackdrop();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

/// Soft radial glow at the top — its color slides between accents when the
/// active slide changes. Adds atmosphere without dominating the design.
class _AccentGlow extends StatelessWidget {
  const _AccentGlow({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.5),
              radius: 0.9,
              colors: [
                color.withValues(alpha: 0.32),
                color.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridOverlay extends StatelessWidget {
  const _DotGridOverlay();
  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _DotGridPainter()),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.04);
    const step = 22.0;
    const dotR = 1.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), dotR, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) => false;
}

// --------------------------------------------------------------------------
// Header bits
// --------------------------------------------------------------------------

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDark.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'KharchaSplit',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFC6CCD6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Skip',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Primary CTA with accent-glow shadow
// --------------------------------------------------------------------------

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.38),
                  blurRadius: 30,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0A0E14),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF0A0E14),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
