import 'dart:math' as math;

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
import 'group_archived_banner.dart';
import 'group_detail_action_chips.dart';
import 'group_detail_large_sidebar.dart';
import 'group_detail_summary.dart';
import 'group_ledger_list.dart';
import 'group_lifecycle_actions.dart';

/// Widest the single-column list grows on standard (600–1100px) screens.
const double _standardMaxWidth = 760;

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

/// Invalidate everything group detail and its sub-pages show (expenses,
/// payments, members, balances, pending payments), then await the main
/// fetch so the [RefreshIndicator] hides the moment fresh data lands.
/// Totals, Balances and the ledger all derive from [groupDetailProvider].
Future<void> refreshGroupDetail(String groupId, WidgetRef ref) async {
  HapticService.instance.thresholdCrossed();
  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(pendingIncomingSettlementsProvider(groupId));
  ref.invalidate(pendingOutgoingSettlementsProvider(groupId));
  await ref.read(groupDetailProvider(groupId).future);
}

/// Compact (<600px) and standard (600–1100px): one scroll view — cover
/// banner, name and balances, action chips, then the month-grouped list of
/// expenses and payments. Standard centres everything below the banner.
class GroupDetailScrollLayout extends ConsumerWidget {
  const GroupDetailScrollLayout({
    super.key,
    required this.detail,
    required this.myId,
    required this.isAdmin,
    required this.topBar,
  });

  final GroupDetail detail;
  final String? myId;
  final bool isAdmin;

  /// The collapsing banner bar ([GroupDetailSliverBar]).
  final Widget topBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width < 600
        ? 0.0
        : math.max(8.0, (width - _standardMaxWidth) / 2);
    final groupId = detail.group.id;
    return RefreshIndicator(
      // Below the pinned bar so the spinner isn't hidden behind it.
      edgeOffset: kToolbarHeight + MediaQuery.paddingOf(context).top,
      onRefresh: () => refreshGroupDetail(groupId, ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          topBar,
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GroupDetailSummary(
                    detail: detail,
                    myId: myId,
                    onBalancesTap: () =>
                        openGroupPage(context, groupId, 'balances'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: buildGroupArchivedBanner(
                      context,
                      ref,
                      detail,
                      isAdmin,
                      bottomGap: 8,
                    ),
                  ),
                  GroupDetailActionChips(detail: detail),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          GroupLedgerSliver(
            groupId: groupId,
            horizontalInset: inset,
            onAddExpense: () => navigateToAddGroupExpense(
              groupId,
              context,
              archived: detail.group.isArchived,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large (>1100px): the banner, balances, chips and members in a left
/// pane; the expense and payment list with its Add expense button on the
/// right. Capped and centred so the panes don't drift apart on very wide
/// displays.
class GroupDetailLargeLayout extends ConsumerWidget {
  const GroupDetailLargeLayout({
    super.key,
    required this.detail,
    required this.myId,
    required this.isAdmin,
    required this.topBar,
  });

  final GroupDetail detail;
  final String? myId;
  final bool isAdmin;
  final Widget topBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupId = detail.group.id;
    final archived = detail.group.isArchived;
    void onAdd() =>
        navigateToAddGroupExpense(groupId, context, archived: archived);

    return WebContentColumn(
      width: ContentWidth.wide,
      gutter: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: CustomScrollView(
              slivers: [
                topBar,
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GroupDetailSummary(
                        detail: detail,
                        myId: myId,
                        horizontalPadding: 32,
                        onBalancesTap: () =>
                            openGroupPage(context, groupId, 'balances'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: buildGroupArchivedBanner(
                          context,
                          ref,
                          detail,
                          isAdmin,
                          bottomGap: 12,
                        ),
                      ),
                      GroupDetailActionChips(detail: detail),
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: buildGroupMembersSection(
                          groupId,
                          context,
                          isDark,
                          detail,
                          ref,
                          myId,
                          isAdmin,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                border: Border(
                  left: BorderSide(color: AppColors.divider(isDark)),
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () => refreshGroupDetail(groupId, ref),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _LargePaneHeader(archived: archived, onAdd: onAdd),
                    ),
                    GroupLedgerSliver(groupId: groupId, onAddExpense: onAdd),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Expenses" title with the Add expense button — the desktop stand-in for
/// the phone's floating button. Archived: greyed out, the tap explains why.
class _LargePaneHeader extends StatelessWidget {
  const _LargePaneHeader({required this.archived, required this.onAdd});

  final bool archived;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                AppStrings.expenses,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary(isDark),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: Icon(
              archived
                  ? Icons.lock_outline_rounded
                  : Icons.receipt_long_rounded,
              size: 18,
            ),
            label: const Text(AppStrings.addExpense),
            style: FilledButton.styleFrom(
              backgroundColor: archived
                  ? AppColors.textSecondary(isDark)
                  : AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}
