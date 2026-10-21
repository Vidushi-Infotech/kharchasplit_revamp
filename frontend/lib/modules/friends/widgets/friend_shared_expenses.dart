import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/group_model.dart';
import '../../groups/state/groups_provider.dart';
import '../state/friend_detail_provider.dart';
import '../state/friends_provider.dart';

/// Expenses involving both you and the friend, as slivers (header + lazy
/// list). Has its own loading / error / empty handling so a slow expense
/// fetch never blocks the balance header.
class FriendSharedExpensesSlivers extends ConsumerWidget {
  const FriendSharedExpensesSlivers({super.key, required this.friendId});

  final String friendId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(friendSharedExpensesProvider(friendId));
    // The hidden non-group group isn't in groupsProvider; its rows read
    // "Non-group".
    final friend = ref.watch(friendByIdProvider(friendId)).value;
    final groupNames = {
      for (final g in ref.watch(groupsProvider).value ?? const <GroupModel>[])
        g.id: g.name,
      for (final g in friend?.groups ?? const <FriendGroupBalance>[])
        if (g.isDirect) g.groupId: AppStrings.nonGroupExpenses,
      ?friend?.directGroupId: AppStrings.nonGroupExpenses,
    };

    Widget title(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            text,
            style: AppTextStyles.headline3(isDark).copyWith(fontSize: 18),
          ),
        );

    return async.when(
      loading: () => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title('Shared expenses'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ShimmerList(type: ShimmerListType.expense, itemCount: 3),
            ),
          ],
        ),
      ),
      error: (err, _) => SliverToBoxAdapter(
        child: ErrorStateWidget(
          title: "Couldn't load shared expenses",
          message: err.toString(),
          onRetry: () => ref.invalidate(friendSharedExpensesProvider(friendId)),
        ),
      ),
      data: (expenses) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: title('Shared expenses (${expenses.length})'),
          ),
          if (expenses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Text(
                  'No shared expenses yet',
                  style: AppTextStyles.body2(isDark),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return Semantics(
                  button: true,
                  label: 'Expense ${expense.title} on '
                      '${DateFormatter.display(expense.date)}',
                  child: ExpenseCard(
                    expense: expense,
                    showGroup: true,
                    groupName: groupNames[expense.groupId],
                    groupIsDirect: expense.groupId != null &&
                        expense.groupId == friend?.directGroupId,
                    onTap: () => context.push('/expense/${expense.id}'),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
