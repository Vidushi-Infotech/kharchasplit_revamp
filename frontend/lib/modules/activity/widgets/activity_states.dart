import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Space under the last row so the floating "Add expense" button never
/// covers it (the web shell has no such button).
double activityBottomReserve(BuildContext context) =>
    shellBottomReserve(context, context.widthTier, compact: 88);

/// Nothing in the feed (or nothing under the chosen filter).
class ActivityEmptyState extends StatelessWidget {
  const ActivityEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 80, 20, activityBottomReserve(context)),
      children: [
        Icon(Icons.timeline_rounded, size: 40, color: AppColors.brand),
        const SizedBox(height: 16),
        Text(
          AppStrings.noActivityYet,
          textAlign: TextAlign.center,
          style: AppTextStyles.body1(
            isDark,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.noActivityHint,
          textAlign: TextAlign.center,
          style: AppTextStyles.body2(
            isDark,
          ).copyWith(color: AppColors.textSecondary(isDark), height: 1.4),
        ),
      ],
    );
  }
}

/// Skeleton rows while the first page loads.
class ActivityLoadingState extends StatelessWidget {
  const ActivityLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.inputFill(isDark);
    Widget bar(double widthFactor) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return ListView.builder(
      padding: EdgeInsets.only(bottom: activityBottomReserve(context)),
      itemCount: 6,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [bar(0.9), const SizedBox(height: 8), bar(0.4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Load failed with nothing cached.
class ActivityErrorState extends StatelessWidget {
  const ActivityErrorState({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 80, 20, activityBottomReserve(context)),
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 40,
          color: AppColors.textSecondary(isDark),
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.couldNotLoadActivity,
          textAlign: TextAlign.center,
          style: AppTextStyles.body1(
            isDark,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
