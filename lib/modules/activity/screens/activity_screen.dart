import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../components/components.dart';
import '../state/activity_feed_provider.dart';
import '../widgets/activity_card.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final filter = ref.watch(activityFilterProvider);
    final feedAsync = ref.watch(filteredActivityFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Activity'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(context, isDark, filter, ref),
          // Activity feed
          Expanded(
            child: feedAsync.when(
              loading: () => const ShimmerList(type: ShimmerListType.activity),
              error: (err, stack) => ErrorStateWidget(
                title: 'Failed to load activities',
                message: 'Unable to fetch activity feed. Please try again.',
                onRetry: () {
                  // Trigger refresh
                },
              ),
              data: (activities) {
                if (activities.isEmpty) {
                  return EmptyStateWidget.noActivity();
                }
                return _buildActivityList(activities);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(
    BuildContext context,
    bool isDark,
    ActivityFilter selectedFilter,
    WidgetRef ref,
  ) {
    return Container(
      color: AppColors.surface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              context,
              isDark,
              'All',
              ActivityFilter.all,
              selectedFilter,
              ref,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context,
              isDark,
              'Expenses',
              ActivityFilter.expenses,
              selectedFilter,
              ref,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context,
              isDark,
              'Settled',
              ActivityFilter.settlements,
              selectedFilter,
              ref,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context,
              isDark,
              'Groups',
              ActivityFilter.groups,
              selectedFilter,
              ref,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    bool isDark,
    String label,
    ActivityFilter filter,
    ActivityFilter selectedFilter,
    WidgetRef ref,
  ) {
    final isSelected = filter == selectedFilter;

    return Semantics(
      button: true,
      label: '$label filter button${isSelected ? ' - selected' : ''}',
      onTap: () => ref.read(activityFilterProvider.notifier).state = filter,
      child: GestureDetector(
        onTap: () => ref.read(activityFilterProvider.notifier).state = filter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.divider(isDark),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body2(isDark).copyWith(
              fontSize: 13,
              color: isSelected ? Colors.white : AppColors.textPrimary(isDark),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList(List<dynamic> activities) {
    // Group activities by date
    final groupedActivities = <String, List<dynamic>>{};
    for (final activity in activities) {
      final dateKey = DateFormatter.groupHeaderDate(activity.timestamp);
      groupedActivities.putIfAbsent(dateKey, () => []).add(activity);
    }

    final dateKeys = groupedActivities.keys.toList();

    return ListView.builder(
      itemCount: dateKeys.length,
      itemBuilder: (context, dateIndex) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dateKey = dateKeys[dateIndex];
        final activitiesForDate = groupedActivities[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                dateKey,
                style: AppTextStyles.caption(isDark).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
            // Activities for this date
            ...activitiesForDate.map((activity) => Semantics(
              button: true,
              label: 'Activity - ${(activity as dynamic).description}',
              child: ActivityCard(activity: activity as dynamic),
            )),
          ],
        );
      },
    );
  }
}
