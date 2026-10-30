import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/buttons/glass_icon_button.dart';
import '../../../components/headers/glass_large_title.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/activity_model.dart';
import '../../auth/state/auth_provider.dart';
import '../state/activity_feed_provider.dart';
import '../state/activity_sentence.dart';
import '../state/activity_tap.dart';
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
    final maxWidth = width < 600
        ? double.infinity
        : (width < 1100 ? 640.0 : 760.0);
    final filterStrip = _FilterStrip(
      selected: filter,
      onSelect: (f) => ref.read(activityFilterProvider.notifier).state = f,
    );
    final divider = Divider(height: 1, color: AppColors.divider(isDark));

    if (GlassIconButton.isGlass) {
      // iOS 26: large title that collapses into the button row on scroll;
      // the filter strip scrolls with the feed, right under the title.
      final top = GlassLargeTitleFrame.topInset(context);
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        body: GlassLargeTitleFrame(
          title: AppStrings.activity,
          leading: GlassBackButton.appBarLeading(
            context,
            implyLeading: context.canPop(),
          ),
          actions: [
            if (unreadCount > 0)
              GlassIconButton(
                icon: Icons.done_all_rounded,
                sfSymbol: 'checkmark.circle',
                tooltip: AppStrings.markAllRead,
                onPressed: notifier.markAllAsRead,
              ),
            const DonateHeartButton(size: 38, iconSize: 18),
          ],
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: RefreshIndicator(
                color: AppColors.brand,
                edgeOffset: top,
                onRefresh: notifier.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: top)),
                    SliverToBoxAdapter(child: filterStrip),
                    SliverToBoxAdapter(child: divider),
                    feedAsync.when(
                      loading: () => const SliverToBoxAdapter(
                        child: ActivityLoadingState(embedded: true),
                      ),
                      error: (_, _) => SliverToBoxAdapter(
                        child: ActivityErrorState(
                          onRetry: notifier.refresh,
                          embedded: true,
                        ),
                      ),
                      data: (items) => items.isEmpty
                          ? const SliverToBoxAdapter(
                              child: ActivityEmptyState(embedded: true),
                            )
                          : _ActivityList(items: items, sliver: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.background(isDark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Activity is a bottom tab: back only when it was pushed.
        automaticallyImplyLeading: context.canPop(),
        leading: GlassBackButton.appBarLeading(
          context,
          implyLeading: context.canPop(),
        ),
        titleSpacing: context.canPop() ? 0 : 16,
        title: const Text(AppStrings.activity),
        actions: [
          if (unreadCount > 0)
            GlassIconButton.isGlass
                ? GlassTextButton(
                    label: AppStrings.markAllRead,
                    onPressed: notifier.markAllAsRead,
                  )
                : TextButton(
                    onPressed: notifier.markAllAsRead,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                    ),
                    child: const Text(AppStrings.markAllRead),
                  ),
          if (unreadCount > 0) const GlassGap(),
          const DonateHeartButton(size: 38, iconSize: 18),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              filterStrip,
              divider,
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
  const _ActivityList({required this.items, this.sliver = false});

  final List<ActivityModel> items;

  /// Rows as a sliver for the iOS 26 large-title scroll view; a
  /// [ListView] otherwise.
  final bool sliver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    final notifier = ref.read(activityFeedProvider.notifier);
    final bottom = EdgeInsets.only(bottom: activityBottomReserve(context));
    Widget row(BuildContext context, int i) {
      // Near the end: fetch the next page (the feed is paged by 50).
      if (i >= items.length - 5) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => notifier.loadMore(),
        );
      }
      final a = items[i];
      final sentence = buildActivitySentence(
        a,
        myUserId: me?.id,
        myName: me?.name,
      );
      final tap = activityTap(a, myUserId: me?.id);
      final isMine = me != null && a.actorId == me.id;
      return ActivityRow(
        activity: a,
        sentence: sentence,
        badgeName: isMine ? me.name : sentence.actorName,
        showDivider: i < items.length - 1,
        onTap: () {
          if (!a.isRead) notifier.markAsRead(a.id);
          final notice = tap.notice;
          if (notice != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(notice)));
          }
          final route = tap.route;
          if (route != null) context.push(route);
        },
      );
    }

    if (sliver) {
      return SliverPadding(
        padding: bottom,
        sliver: SliverList.builder(itemCount: items.length, itemBuilder: row),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: bottom,
      itemCount: items.length,
      itemBuilder: row,
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
