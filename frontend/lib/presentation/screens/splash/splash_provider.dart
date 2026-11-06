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
      // No artificial delay here: the native splash already covers the
      // engine boot, and the only thing this screen must wait for is the
      // secure-storage read. Every extra second is pure cold-start latency.
      final tokens = ref.read(tokenStorageProvider);
      final results = await Future.wait([
        tokens.readAccessToken(),
        tokens.readUser(),
      ]);
      final accessToken = results[0] as String?;
      final storedUser = results[1] as Map<String, dynamic>?;
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
