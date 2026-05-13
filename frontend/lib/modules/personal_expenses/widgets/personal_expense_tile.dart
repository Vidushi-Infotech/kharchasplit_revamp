import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/personal_expense_model.dart';
import '../state/personal_expenses_provider.dart';

class PersonalExpenseTile extends ConsumerWidget {
  const PersonalExpenseTile({super.key, required this.expense});

  final PersonalExpenseModel expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _hexToColor(expense.category.colorHex);

    return Semantics(
      label:
          '${expense.title}, ${CurrencyFormatter.format(expense.amount, currency: expense.currency)}, '
          '${expense.category.name}',
      child: Dismissible(
        key: ValueKey(expense.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.errorBg(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_rounded,
              color: AppColors.errorText(isDark), size: 24),
        ),
        confirmDismiss: (_) => _confirmDelete(context, isDark),
        onDismissed: (_) =>
            ref.read(personalExpensesProvider.notifier).deleteExpense(expense.id),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0,
          color: AppColors.cardBg(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.divider(isDark), width: 1),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(expense.category.icon,
                  color: categoryColor, size: 22),
            ),
            title: Text(
              expense.title,
              style: AppTextStyles.body1(isDark)
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${expense.category.name} · ${DateFormat('h:mm a').format(expense.expenseDate)}',
              style: AppTextStyles.caption(isDark),
            ),
            trailing: Text(
              CurrencyFormatter.format(expense.amount,
                  currency: expense.currency),
              style: AppTextStyles.body1(isDark)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, bool isDark) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('"${expense.title}" will be removed permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.errorText(isDark)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
