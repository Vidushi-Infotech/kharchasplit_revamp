import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding state provider (Riverpod 3.x)
final onboardingPageProvider =
    NotifierProvider<OnboardingNotifier, int>(
      OnboardingNotifier.new,
    );

/// Check if user has seen onboarding
final hasSeenOnboardingProvider =
    FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('has_seen_onboarding') ?? false;
});

/// Notifier for managing onboarding state
class OnboardingNotifier extends Notifier<int> {
  static const int totalPages = 3;

  @override
  int build() => 0;

  void nextPage() {
    if (state < totalPages - 1) {
      state = state + 1;
    }
  }

  void previousPage() {
    if (state > 0) {
      state = state - 1;
    }
  }

  void goToPage(int index) {
    if (index >= 0 && index < totalPages) {
      state = index;
    }
  }

  /// Mark onboarding as seen and save to preferences
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (e) {
      // Silently fail
    }
  }

  bool get isLastPage => state == totalPages - 1;
  bool get isFirstPage => state == 0;
}
