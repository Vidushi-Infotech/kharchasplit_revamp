import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'splash_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splashState = ref.watch(splashProviderProvider);

    // Route based on stored auth state once splash finishes initializing.
    ref.listen(splashProviderProvider, (previous, next) {
      switch (next) {
        case SplashState.authenticated:
          context.go('/home/dashboard');
          break;
        case SplashState.unauthenticated:
        case SplashState.ready:
          context.go('/onboarding');
          break;
        case SplashState.initializing:
          break;
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RepaintBoundary(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LogoWidget(splashState: splashState),
              const SizedBox(height: 40),
              _LoadingIndicator(splashState: splashState),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  final SplashState splashState;

  const _LogoWidget({
    Key? key,
    required this.splashState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = size.width * 0.4;

    return AnimatedOpacity(
      opacity: splashState == SplashState.initializing ? 1.0 : 0.8,
      duration: const Duration(milliseconds: 800),
      child: Image.asset(
        'assets/images/logo.png',
        width: logoSize,
        height: logoSize,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final SplashState splashState;

  const _LoadingIndicator({
    Key? key,
    required this.splashState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Initializing...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}
