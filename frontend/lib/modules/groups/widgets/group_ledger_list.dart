import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_ledger.dart';
import 'group_ledger_rows.dart';

/// Expenses and payments of the group as one lazily built, month-grouped
/// sliver. Empty groups get [GroupLedgerEmpty] filling the rest of the
/// viewport instead.
class GroupLedgerSliver extends ConsumerWidget {
  const GroupLedgerSliver({
    super.key,
    required this.groupId,
    required this.onAddExpense,
    this.horizontalInset = 0,
  });

  final String groupId;
  final VoidCallback onAddExpense;

  /// Side inset that centres the list on wider screens.
  final double horizontalInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(groupLedgerProvider(groupId)) ?? const [];
    final myId = ref.watch(myIdProvider);
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: GroupLedgerEmpty(onAddExpense: onAddExpense),
      );
    }
    final monthFormat = DateFormat('MMMM yyyy');
    return SliverPadding(
      // Bottom room so the last row clears the extended FAB.
      padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 96),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => switch (items[i]) {
          LedgerMonthHeader(:final month) => MonthSectionHeader(
            monthFormat.format(month),
          ),
          LedgerExpense(:final expense) => GroupExpenseRow(
            key: ValueKey('e_${expense.id}'),
            expense: expense,
            myId: myId,
          ),
          LedgerPayment(:final settlement) => GroupPaymentRow(
            key: ValueKey('s_${settlement.id}'),
            settlement: settlement,
            myId: myId,
            groupId: groupId,
          ),
        },
      ),
    );
  }
}

/// "No expenses here yet" with an Add expense button.
class GroupLedgerEmpty extends StatelessWidget {
  const GroupLedgerEmpty({super.key, required this.onAddExpense});

  final VoidCallback onAddExpense;

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
            AppStrings.noExpensesHereYet,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.noExpensesHereHint,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddExpense,
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text(AppStrings.addExpense),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
