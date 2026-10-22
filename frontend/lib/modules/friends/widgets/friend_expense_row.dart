import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/list/list_components.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/expense_model.dart';
import '../../expenses/widgets/recurring_badge.dart';
import '../../outbox/widgets/sync_badge.dart';
import '../state/friend_detail_view.dart';

/// Flat shared-expense row on friend detail: "Oct 18 [🍴] Dinner / Goa
/// trip · Test R. paid ₹900.00" with "you borrowed ₹450.00" on the right.
/// Label and amount come from one [FriendExpenseRowView] tone.
class FriendExpenseRow extends StatelessWidget {
  const FriendExpenseRow({
    super.key,
    required this.expense,
    required this.myId,
    this.groupName,
  });

  final ExpenseModel expense;
  final String? myId;

  /// Shown before the payer line; null for non-group expenses.
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final view = friendExpenseRowView(expense, myId, groupName: groupName);
    final amountText = CurrencyFormatter.format(
      view.amount,
      currency: expense.currency,
    );

    return KsListRow(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DateBadge(expense.date.toLocal()),
          const SizedBox(width: 10),
          CategoryTile.forCategory(expense.category, size: 40),
        ],
      ),
      title: expense.title,
      subtitles: [
        view.subtitle,
        if (expense.isRecurring || expense.isPendingSync)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (expense.isRecurring)
                RecurringBadge(isDark: isDark, compact: true),
              if (expense.isPendingSync)
                SyncBadge(
                  isDark: isDark,
                  failed: expense.syncState == 'failed',
                ),
            ],
          ),
      ],
      trailing: BalanceAmountLabel(
        tone: view.tone,
        amount: view.amount,
        currency: expense.currency,
        forExpense: true,
        label: view.label,
      ),
      semanticsLabel: '${expense.title}, ${view.subtitle}, '
          '${view.label}${view.showsAmount ? ' $amountText' : ''}',
      // Not on the server yet: show it in Unsynced changes.
      onTap: () => context.push(
        expense.isPendingSync
            ? '/home/profile/unsynced'
            : '/expense/${expense.id}',
      ),
    );
  }
}
