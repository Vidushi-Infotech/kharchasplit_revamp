import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/personal_expense_model.dart';
import '../state/personal_expenses_provider.dart';

/// Compact, swipe-to-delete row for a single personal expense.
/// Designed to sit inside a parent group card; do NOT wrap with another card.
class PersonalExpenseTile extends ConsumerWidget {
  const PersonalExpenseTile({
    super.key,
    required this.expense,
    this.showDivider = true,
  });

  final PersonalExpenseModel expense;
  final bool showDivider;

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
          color: AppColors.errorBg(isDark),
          child: Icon(
            Icons.delete_rounded,
            color: AppColors.errorText(isDark),
            size: 22,
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context, isDark),
        onDismissed: (_) => ref
            .read(personalExpensesProvider.notifier)
            .deleteExpense(expense.id),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _CategoryTile(
                        icon: expense.category.icon,
                        color: categoryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              expense.title,
                              style: AppTextStyles.body1(isDark).copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${expense.category.name} · ${DateFormat('h:mm a').format(expense.expenseDate)}',
                              style: AppTextStyles.caption(isDark).copyWith(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '-${CurrencyFormatter.format(expense.amount, currency: expense.currency)}',
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
              ),
          ],
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText(isDark),
            ),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
