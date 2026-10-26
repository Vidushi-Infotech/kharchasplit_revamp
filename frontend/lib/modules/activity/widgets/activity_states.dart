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

/// Physics for a state's list: its own scroll view normally, or laid out
/// in full inside the iOS 26 large-title scroll view when [embedded].
ScrollPhysics _statePhysics(bool embedded) => embedded
    ? const NeverScrollableScrollPhysics()
    : const AlwaysScrollableScrollPhysics();

/// Nothing in the feed (or nothing under the chosen filter).
class ActivityEmptyState extends StatelessWidget {
  const ActivityEmptyState({super.key, this.embedded = false});

  /// Inside an outer scroll view (iOS 26 large title): no scrolling of
  /// its own, sized to its content.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: _statePhysics(embedded),
      shrinkWrap: embedded,
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
  const ActivityLoadingState({super.key, this.embedded = false});

  /// See [ActivityEmptyState.embedded].
  final bool embedded;

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
      physics: embedded ? _statePhysics(embedded) : null,
      shrinkWrap: embedded,
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
  const ActivityErrorState({
    super.key,
    required this.onRetry,
    this.embedded = false,
  });

  final Future<void> Function() onRetry;

  /// See [ActivityEmptyState.embedded].
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: _statePhysics(embedded),
      shrinkWrap: embedded,
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
