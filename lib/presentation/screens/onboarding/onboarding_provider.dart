import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/onboarding_constants.dart';

final onboardingPageProvider =
    NotifierProvider<OnboardingNotifier, int>(
      OnboardingNotifier.new,
    );

class OnboardingNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void nextPage() {
    if (state < onboardingPages.length - 1) {
      state = state + 1;
    }
  }

  void previousPage() {
    if (state > 0) {
      state = state - 1;
    }
  }

  void goToPage(int index) {
    if (index >= 0 && index < onboardingPages.length) {
      state = index;
    }
  }

  void skipOnboarding() {
    // TODO: Navigate to next screen (auth or dashboard)
    state = onboardingPages.length;
  }

  bool get isLastPage => state == onboardingPages.length - 1;
  bool get isFirstPage => state == 0;
}
