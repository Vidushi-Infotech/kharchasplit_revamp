import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// Shown when a URL does not match any route.
///
/// Reachable in practice only on the web, where users type, bookmark and share
/// URLs. Without it go_router falls back to its raw debug page.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, this.location});

  final String? location;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 56,
                  color: AppColors.textSecondary(isDark),
                ),
                const SizedBox(height: 20),
                Text(
                  'This page does not exist',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  location == null
                      ? 'The link you followed may be broken or out of date.'
                      : 'Nothing lives at $location. The link may be broken '
                            'or out of date.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.go('/home/dashboard'),
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: const Text('Go to dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
