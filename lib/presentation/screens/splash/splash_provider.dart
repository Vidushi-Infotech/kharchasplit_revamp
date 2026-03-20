import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SplashState { initializing, ready, authenticated, unauthenticated }

final splashProviderProvider =
    StateNotifierProvider<SplashNotifier, SplashState>((ref) {
  return SplashNotifier();
});

class SplashNotifier extends StateNotifier<SplashState> {
  SplashNotifier() : super(SplashState.initializing) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Simulate splash duration and initialization
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Check authentication status here
      // For now, redirect to login
      state = SplashState.unauthenticated;
    } catch (e) {
      state = SplashState.unauthenticated;
    }
  }

  void reset() {
    state = SplashState.initializing;
    _initialize();
  }
}
