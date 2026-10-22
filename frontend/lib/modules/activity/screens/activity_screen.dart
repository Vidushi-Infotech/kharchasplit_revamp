import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/donate_heart_button.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/activity_model.dart';
import '../../auth/state/auth_provider.dart';
import '../state/activity_feed_provider.dart';
import '../state/activity_sentence.dart';
import '../widgets/activity_row.dart';
import '../widgets/activity_states.dart';

/// Activity tab: a flat feed of sentences — `You added "Dinner" in
/// "Goa trip".` — newest first, with a filter strip and "Mark all read".
/// Compact is full width; standard and large center the feed in a
/// reading-width column.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final filter = ref.watch(activityFilterProvider);
    final feedAsync = ref.watch(filteredActivityFeedProvider);
    final unreadCount = (ref.watch(activityFeedProvider).value ?? const [])
        .where((a) => !a.isRead)
        .length;
    final notifier = ref.read(activityFeedProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.background(isDark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Activity is a bottom tab: back only when it was pushed.
        automaticallyImplyLeading: context.canPop(),
        titleSpacing: context.canPop() ? 0 : 16,
        title: const Text(AppStrings.activity),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: notifier.markAllAsRead,
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: const Text(AppStrings.markAllRead),
            ),
          const DonateHeartButton(size: 38, iconSize: 18),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width < 600
                ? double.infinity
                : (width < 1100 ? 640 : 760),
          ),
          child: Column(
            children: [
              _FilterStrip(
                selected: filter,
                onSelect: (f) =>
                    ref.read(activityFilterProvider.notifier).state = f,
              ),
              Divider(height: 1, color: AppColors.divider(isDark)),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: notifier.refresh,
                  child: feedAsync.when(
                    loading: () => const ActivityLoadingState(),
                    error: (_, _) =>
                        ActivityErrorState(onRetry: notifier.refresh),
                    data: (items) => items.isEmpty
                        ? const ActivityEmptyState()
                        : _ActivityList(items: items),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityList extends ConsumerWidget {
  const _ActivityList({required this.items});

  final List<ActivityModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    final notifier = ref.read(activityFeedProvider.notifier);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: activityBottomReserve(context)),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final a = items[i];
        final sentence = buildActivitySentence(
          a,
          myUserId: me?.id,
          myName: me?.name,
        );
        final route = activityRoute(a);
        final isMine = me != null && a.actorId == me.id;
        return ActivityRow(
          activity: a,
          sentence: sentence,
          badgeName: isMine ? me.name : sentence.actorName,
          showDivider: i < items.length - 1,
          onTap: () {
            if (!a.isRead) notifier.markAsRead(a.id);
            if (route != null) context.push(route);
          },
        );
      },
    );
  }
}

/// All · Expenses · Payments · Groups.
class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.selected, required this.onSelect});

  final ActivityFilter selected;
  final ValueChanged<ActivityFilter> onSelect;

  static const _entries = <(ActivityFilter, String)>[
    (ActivityFilter.all, AppStrings.activityFilterAll),
    (ActivityFilter.expenses, AppStrings.activityFilterExpenses),
    (ActivityFilter.settlements, AppStrings.activityFilterSettled),
    (ActivityFilter.groups, AppStrings.activityFilterGroups),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label) = _entries[i];
          final isSelected = value == selected;
          return Semantics(
            button: true,
            selected: isSelected,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: isSelected
                  ? AppColors.brand.withValues(alpha: isDark ? 0.22 : 0.10)
                  : Colors.transparent,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.divider(isDark),
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelect(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      label,
                      style: textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.textSecondary(isDark),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
