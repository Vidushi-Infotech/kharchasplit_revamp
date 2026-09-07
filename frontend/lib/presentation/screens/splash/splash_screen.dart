import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/web_deep_link.dart';
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
          // Read the stored user directly from secure storage — the
          // authProvider hydration is async and may not have populated
          // its state yet, which would falsely send completed users to
          // the profile-setup screen on every cold start.
          ref.read(tokenStorageProvider).readUser().then((storedUser) {
            if (!context.mounted) return;
            final name =
                (storedUser?['name'] as String?)?.trim() ?? '';
            // On cold start we only gate on `name` — without a name the
            // dashboard UI has nothing to render. Email enforcement is
            // already handled at register/login time (the post-auth router
            // sends users to /profile-setup when `needsProfileSetup` is
            // true) and shouldn't re-trigger here just because the cached
            // user payload happens to lack an `email` field. Otherwise a
            // user who legitimately reached the dashboard could be bounced
            // back to setup on every relaunch.
            final needsSetup = name.isEmpty;
            if (needsSetup) {
              WebDeepLink.discard();
              context.go('/profile-setup');
              return;
            }
            // On the web the user may have opened a URL directly; the router
            // parked it here so auth could resolve first. Hand them back to
            // it. Always null on mobile.
            context.go(WebDeepLink.take() ?? '/home/dashboard');
          });
          break;
        case SplashState.unauthenticated:
        case SplashState.ready:
          WebDeepLink.discard();
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
    final size = MediaQuery.sizeOf(context);
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
