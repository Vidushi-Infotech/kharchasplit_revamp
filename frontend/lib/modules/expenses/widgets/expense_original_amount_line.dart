import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../state/fx_rate_text.dart';

/// Expense detail header, under the amount of an expense entered in another
/// currency: "Paid $100.00 · 1 USD = ₹83.12 on 16 Oct". Nothing for one
/// entered in the group's currency.
class ExpenseOriginalAmountLine extends StatelessWidget {
  const ExpenseOriginalAmountLine({super.key, required this.expense});

  final ExpenseModel expense;

  @override
  Widget build(BuildContext context) {
    final line = fxExpenseOriginalLine(expense);
    if (line == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        line,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
