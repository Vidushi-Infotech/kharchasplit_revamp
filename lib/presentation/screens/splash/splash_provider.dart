import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

enum SplashState { initializing, ready, authenticated, unauthenticated }

final splashProviderProvider =
    NotifierProvider<SplashNotifier, SplashState>(SplashNotifier.new);

class SplashNotifier extends Notifier<SplashState> {
  @override
  SplashState build() {
    _initialize();
    return SplashState.initializing;
  }

  Future<void> _initialize() async {
    try {
      final tokens = ref.read(tokenStorageProvider);
      final results = await Future.wait([
        Future.delayed(const Duration(seconds: 2)),
        tokens.readAccessToken(),
        tokens.readUser(),
      ]);
      final accessToken = results[1] as String?;
      final storedUser = results[2] as Map<String, dynamic>?;
      state = (accessToken != null && accessToken.isNotEmpty && storedUser != null)
          ? SplashState.authenticated
          : SplashState.unauthenticated;
    } catch (_) {
      state = SplashState.unauthenticated;
    }
  }

  void reset() {
    state = SplashState.initializing;
    _initialize();
  }
}
