import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/expense_model.dart';
import '../../../models/settlement_model.dart';
import '../../expenses/widgets/recurring_badge.dart';
import '../../outbox/widgets/sync_badge.dart';
import '../state/group_ledger.dart';

/// Leading block shared by both rows: date badge, then the tile.
Widget _leading(DateTime date, Widget tile) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [DateBadge(date.toLocal()), const SizedBox(width: 10), tile],
);

/// Flat expense row: "Oct 18 [🍴] Dinner / Test R. paid ₹1,000.00" with
/// "you borrowed ₹500.00" on the right. Label and amount come from one
/// [ExpenseRowView] tone, so their colors always agree.
class GroupExpenseRow extends StatelessWidget {
  const GroupExpenseRow({super.key, required this.expense, required this.myId});

  final ExpenseModel expense;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final view = expenseRowView(expense, myId);
    final evenButInvolved = view.tone == BalanceTone.settled;
    final label = evenButInvolved
        ? AppStrings.expenseNoBalance
        : view.tone.expenseLabel;
    final amountText = CurrencyFormatter.format(
      view.amount,
      currency: expense.currency,
    );
    final showAmount =
        view.tone == BalanceTone.owed || view.tone == BalanceTone.owe;

    return KsListRow(
      leading: _leading(
        expense.date,
        CategoryTile.forCategory(expense.category, size: 40),
      ),
      title: expense.title,
      subtitles: [
        view.payerLine,
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
        label: label,
      ),
      semanticsLabel:
          '${expense.title}, ${view.payerLine}, '
          '$label${showAmount ? ' $amountText' : ''}',
      // Not on the server yet: show it in Unsynced changes.
      onTap: () => context.push(
        expense.isPendingSync
            ? '/home/profile/unsynced'
            : '/expense/${expense.id}',
      ),
    );
  }
}

/// A payment between members, inline in the same list: money tile and
/// "Test F. paid you ₹200.00". Opens the history with the other person
/// when the viewer is part of it.
class GroupPaymentRow extends StatelessWidget {
  const GroupPaymentRow({
    super.key,
    required this.settlement,
    required this.myId,
    required this.groupId,
  });

  final SettlementModel settlement;
  final String? myId;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = paymentRowTitle(settlement, myId);
    final status = paymentRowStatus(settlement);
    final other = settlement.fromUser.id == myId
        ? settlement.toUser.id
        : settlement.toUser.id == myId
        ? settlement.fromUser.id
        : null;
    final muted = status != null;
    return KsListRow(
      dense: true,
      leading: _leading(
        settlement.date,
        CategoryTile(
          icon: Icons.payments_outlined,
          color: muted ? AppColors.textSecondary(isDark) : AppColors.brand,
          size: 40,
        ),
      ),
      title: title,
      subtitles: [?status],
      semanticsLabel: status == null ? title : '$title, $status',
      onTap: other == null
          ? null
          : () => context.push('/home/groups/$groupId/settlements-with/$other'),
    );
  }
}
