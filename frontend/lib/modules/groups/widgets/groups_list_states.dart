import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shown when the search / balance filter leaves no groups to list.
class GroupsEmptyResultsCard extends StatelessWidget {
  const GroupsEmptyResultsCard({
    super.key,
    required this.isDark,
    required this.query,
  });

  final bool isDark;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 36,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'No groups match this filter'
                : 'No groups match "$query"',
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different filter or search term',
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Full-screen error for a failed groups load, with retry.
class GroupsErrorState extends StatelessWidget {
  const GroupsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.errorText(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load groups",
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.body2(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
