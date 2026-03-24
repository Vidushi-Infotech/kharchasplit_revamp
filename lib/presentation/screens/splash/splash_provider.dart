import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SplashState { initializing, ready, authenticated, unauthenticated }

final splashProviderProvider =
    NotifierProvider<SplashNotifier, SplashState>(
      SplashNotifier.new,
    );

class SplashNotifier extends Notifier<SplashState> {
  @override
  SplashState build() {
    _initialize();
    return SplashState.initializing;
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
