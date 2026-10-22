import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/components.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_ledger.dart';
import '../state/friend_detail_provider.dart';
import '../state/friend_detail_view.dart';
import '../state/friends_provider.dart';
import 'friend_add_expense_button.dart';
import 'friend_expense_row.dart';

/// Expenses shared with the friend as one lazily built, month-grouped
/// sliver of flat rows. Has its own loading / error / empty handling so a
/// slow expense fetch never blocks the balance header.
class FriendSharedExpensesSlivers extends ConsumerWidget {
  const FriendSharedExpensesSlivers({
    super.key,
    required this.friend,
    this.horizontalInset = 0,
    this.bottomPadding = 96,
  });

  final FriendBalance friend;

  /// Side inset that centres the list on wider screens.
  final double horizontalInset;

  /// Room so the last row clears the floating Add expense button.
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendId = friend.user.id;
    final async = ref.watch(friendLedgerProvider(friendId));
    final groupNames = ref.watch(friendGroupNamesProvider(friendId));
    final myId = ref.watch(myIdProvider);
    final padding = EdgeInsets.fromLTRB(
      horizontalInset,
      0,
      horizontalInset,
      bottomPadding,
    );

    return async.when(
      loading: () => SliverPadding(
        padding: padding.add(const EdgeInsets.symmetric(horizontal: 16)),
        // ShimmerList is a ListView: give it a bounded height in a sliver.
        sliver: const SliverToBoxAdapter(
          child: SizedBox(
            height: 288,
            child: ShimmerList(type: ShimmerListType.expense, itemCount: 3),
          ),
        ),
      ),
      error: (err, _) => SliverToBoxAdapter(
        child: ErrorStateWidget(
          title: AppStrings.friendSharedExpensesError,
          message: err.toString(),
          onRetry: () => ref.invalidate(friendSharedExpensesProvider(friendId)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _FriendExpensesEmpty(friend: friend),
          );
        }
        final monthFormat = DateFormat('MMMM yyyy');
        return SliverPadding(
          padding: padding,
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => switch (items[i]) {
              LedgerMonthHeader(:final month) =>
                MonthSectionHeader(monthFormat.format(month)),
              LedgerExpense(:final expense) => FriendExpenseRow(
                  key: ValueKey('e_${expense.id}'),
                  expense: expense,
                  myId: myId,
                  groupName: groupNames[expense.groupId],
                ),
              // The friend ledger holds no payments.
              LedgerPayment() => const SizedBox.shrink(),
            },
          ),
        );
      },
    );
  }
}

/// "No shared expenses yet" with an Add expense button.
class _FriendExpensesEmpty extends StatelessWidget {
  const _FriendExpensesEmpty({required this.friend});

  final FriendBalance friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.friendNoSharedExpenses,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.friendNoSharedExpensesHint(
              friendDisplayName(friend.user.name),
            ),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 20),
          FriendAddExpenseButton(
            friend: friend,
            style: FriendAddExpenseStyle.pill,
          ),
        ],
      ),
    );
  }
}
