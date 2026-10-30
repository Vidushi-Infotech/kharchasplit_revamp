import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/category_model.dart';
import '../../../../models/personal_budget_model.dart';

/// Teal while there's room, orange from 80%, red once over.
Color budgetColor(BudgetLevel level, bool isDark) => switch (level) {
  BudgetLevel.fine => AppColors.brand,
  BudgetLevel.near => AppColors.warning,
  BudgetLevel.over => AppColors.errorText(isDark),
};

/// "₹1,200 left" / "₹300 over".
String budgetRemaining(BudgetStatus b) => b.left >= 0
    ? '${CurrencyFormatter.format(b.left, currency: '₹')} ${AppStrings.budgetLeft}'
    : '${CurrencyFormatter.format(-b.left, currency: '₹')} ${AppStrings.budgetOver}';

/// One category budget: icon, name, a bar of how much is used and what's
/// left. Tap to change it.
class BudgetRow extends StatelessWidget {
  const BudgetRow({super.key, required this.budget, required this.onTap});

  final BudgetStatus budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = CategoryModel.fromId(budget.category)!;
    final color = budgetColor(budget.level, isDark);
    final caption = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark), fontSize: 12);
    return Semantics(
      button: true,
      label:
          '${cat.name}, '
          '${CurrencyFormatter.format(budget.spent, currency: '₹')} '
          '${AppStrings.budgetOf} '
          '${CurrencyFormatter.format(budget.amount, currency: '₹')}, '
          '${budgetRemaining(budget)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(cat.icon, size: 18, color: cat.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat.name,
                            style: AppTextStyles.body1(isDark).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          budgetRemaining(budget),
                          style: caption.copyWith(
                            color: budget.level == BudgetLevel.fine
                                ? AppColors.textSecondary(isDark)
                                : color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: budget.used.clamp(0.0, 1.0),
                        minHeight: 7,
                        color: color,
                        backgroundColor: AppColors.divider(isDark),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${CurrencyFormatter.format(budget.spent, currency: '₹')} '
                      '${AppStrings.budgetOf} '
                      '${CurrencyFormatter.format(budget.amount, currency: '₹')}',
                      style: caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
