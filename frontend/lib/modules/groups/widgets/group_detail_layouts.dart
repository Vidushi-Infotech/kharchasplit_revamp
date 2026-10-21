import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../components/web/web_page.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/services/haptic_service.dart';
import '../../settlements/state/pending_settlements_provider.dart';
import '../state/group_detail_provider.dart';
import 'group_activity_tab.dart';
import 'group_balances_tab.dart';
import 'group_detail_headers.dart';
import 'group_detail_large_sidebar.dart';
import 'group_detail_tabs.dart';
import 'group_archived_banner.dart';
import 'group_expenses_list.dart';
import 'group_lifecycle_actions.dart';
import 'group_sticky_tab_bar_delegate.dart';

/// Opens Add expense for the group. When [archived], explains why instead —
/// the backend would reject the save with 409 GROUP_ARCHIVED anyway.
void navigateToAddGroupExpense(
  String groupId,
  BuildContext context, {
  bool archived = false,
}) {
  if (archived) {
    showGroupArchivedNotice(context);
    return;
  }
  context.pushNamed(
    'add-expense-to-group',
    pathParameters: {'groupId': groupId},
  );
}

Widget buildGroupCompactLayout(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupDetail detail,
  GroupTab tab,
  WidgetRef ref,
  String? myId,
  bool isAdmin,
) {
  // Compact: <600px - full width, single column, tight spacing (16-20px)
  return NestedScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    headerSliverBuilder: (ctx, _) => [
      SliverToBoxAdapter(
        child: buildGroupCompactHeader(
          groupId,
          context,
          isDark,
          detail,
          ref,
          myId,
          isAdmin,
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: GroupStickyTabBarDelegate(
          isDark: isDark,
          child: buildGroupTabs(groupId, context, isDark, tab, ref),
        ),
      ),
    ],
    body: buildGroupTabBody(groupId, context, ref, isDark, tab, detail, myId),
  );
}

/// Invalidate every provider that feeds any of the 3 tabs on this screen,
/// then await the main fetch so the [RefreshIndicator] hides at the
/// moment fresh data lands. Called from:
///   * the outer RefreshIndicator (top-of-header pull)
///   * inline RefreshIndicators inside each tab body
///   * GroupActivityTab's onRefresh
/// Same callback everywhere so users can pull from ANY tab and get the
/// full group state refreshed in one shot.
Future<void> refreshAllGroupTabs(String groupId, WidgetRef ref) async {
  HapticService.instance.thresholdCrossed();
  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(pendingIncomingSettlementsProvider(groupId));
  ref.invalidate(pendingOutgoingSettlementsProvider(groupId));
  // groupFeedProvider (activity feed) derives from groupDetailProvider, so
  // invalidating the parent above already refreshes the feed — no separate
  // invalidate call needed.
  await ref.read(groupDetailProvider(groupId).future);
}

/// Body for whichever tab is currently selected. Lives below the pinned
/// tab bar inside [NestedScrollView]; each branch is responsible for its
/// own internal scrolling.
///
/// Each branch wraps its scrollable in a [RefreshIndicator] so the pull
/// gesture works from anywhere inside the tab — not just when the user
/// has scrolled to the absolute top (which is the only place the outer
/// RefreshIndicator triggers when wrapping a [NestedScrollView]).
Widget buildGroupTabBody(
  String groupId,
  BuildContext context,
  WidgetRef ref,
  bool isDark,
  GroupTab tab,
  GroupDetail detail,
  String? myId,
) {
  switch (tab) {
    case GroupTab.expenses:
      return RefreshIndicator(
        onRefresh: () => refreshAllGroupTabs(groupId, ref),
        child: buildGroupExpensesList(context, isDark, detail),
      );
    case GroupTab.balances:
      // _buildBalancesTab returns a ListView.builder (its own scrollable).
      // Do NOT wrap it in a SingleChildScrollView — that gives the ListView
      // an unbounded viewport, so the builder never knows how many items to
      // render and BalanceSummaryCards / SplitLogRow rows silently vanish.
      // Two nested scrollables also fight over the gesture, killing the
      // scroll feel. RefreshIndicator attaches directly to the ListView's
      // scroll position the same way it does for the Expenses tab.
      return RefreshIndicator(
        onRefresh: () => refreshAllGroupTabs(groupId, ref),
        child: buildGroupBalancesTab(
          groupId,
          context,
          ref,
          isDark,
          detail,
          myId,
        ),
      );
    case GroupTab.activity:
      // GroupActivityTab has its own RefreshIndicator wired to the same
      // shared callback so all 3 tabs behave identically.
      return GroupActivityTab(
        groupId: groupId,
        onRefresh: () => refreshAllGroupTabs(groupId, ref),
      );
  }
}

Widget buildGroupStandardLayout(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupDetail detail,
  GroupTab tab,
  WidgetRef ref,
  String? myId,
  bool isAdmin,
) {
  // Standard: 600-1100px — same sticky-tabs pattern as compact, with
  // the standard header replacing the compact one.
  return NestedScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    headerSliverBuilder: (ctx, _) => [
      SliverToBoxAdapter(
        child: buildGroupStandardHeader(
          groupId,
          context,
          isDark,
          detail,
          ref,
          myId,
          isAdmin,
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: GroupStickyTabBarDelegate(
          isDark: isDark,
          child: buildGroupTabs(groupId, context, isDark, tab, ref),
        ),
      ),
    ],
    body: buildGroupTabBody(groupId, context, ref, isDark, tab, detail, myId),
  );
}

Widget buildGroupLargeLayout(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupDetail detail,
  GroupTab tab,
  WidgetRef ref,
  String? myId,
  bool isAdmin,
) {
  // Large: >1100px — info pane + content pane.
  //
  // Capped and centred: without a cap the two panes just keep stretching, so
  // on a 1920px display the member list and the expense rows end up hundreds
  // of pixels apart with nothing in between.
  return WebContentColumn(
    width: ContentWidth.wide,
    gutter: false,
    child: Row(
      children: [
        // Left sidebar - Group info and members (32% width)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildGroupArchivedBanner(
                    context,
                    ref,
                    detail,
                    isAdmin,
                    bottomGap: 24,
                  ),
                  buildGroupLargeHeader(context, isDark, detail, myId),
                  const SizedBox(height: 32),
                  buildGroupMembersSection(
                    groupId,
                    context,
                    isDark,
                    detail,
                    ref,
                    myId,
                    isAdmin,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right content area - Tabs + Expenses/Balances (68% width)
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              border: Border(
                left: BorderSide(color: AppColors.divider(isDark), width: 1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: buildGroupTabs(groupId, context, isDark, tab, ref),
                    ),
                    // The mobile FAB has no desktop equivalent, so the create
                    // action lives on the pane it belongs to.
                    // Archived: greyed out, but the tap still explains why.
                    if (tab == GroupTab.expenses)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: FilledButton.icon(
                          onPressed: () => navigateToAddGroupExpense(
                            groupId,
                            context,
                            archived: detail.group.isArchived,
                          ),
                          icon: Icon(
                            detail.group.isArchived
                                ? Icons.lock_outline_rounded
                                : Icons.add_rounded,
                            size: 18,
                          ),
                          label: const Text(AppStrings.addExpense),
                          style: FilledButton.styleFrom(
                            backgroundColor: detail.group.isArchived
                                ? AppColors.textSecondary(isDark)
                                : AppColors.brand,
                          ),
                        ),
                      ),
                  ],
                ),
                // Hairline divider between tabs and content panel — matches
                // the compact/standard layouts' sticky bar separator.
                Container(
                  height: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.5),
                ),
                Expanded(
                  child: buildGroupTabBody(
                    groupId,
                    context,
                    ref,
                    isDark,
                    tab,
                    detail,
                    myId,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
