import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/personal_budget_model.dart';
import 'budget_row.dart';

/// The whole month's budget: a ring of how much is used, what's left, and
/// how much can still go each day. Without one, an invitation to set it.
class MonthBudgetCard extends StatelessWidget {
  const MonthBudgetCard({
    super.key,
    required this.budget,
    required this.spent,
    required this.onTap,
  });

  /// Null when no monthly budget is set.
  final BudgetStatus? budget;

  /// This month's spending, shown even without a budget.
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = budget;
    return Material(
      color: AppColors.cardBg(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.divider(isDark)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: b == null ? _Unset(spent: spent) : _Set(budget: b),
        ),
      ),
    );
  }
}

class _Set extends StatelessWidget {
  const _Set({required this.budget});

  final BudgetStatus budget;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = budgetColor(budget.level, isDark);
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = lastDay - now.day + 1;
    final perDay = budget.left > 0 ? budget.left / daysLeft : 0.0;
    final caption = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark));

    return Row(
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: budget.used.clamp(0.0, 1.0),
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: AppColors.divider(isDark),
                ),
              ),
              Text(
                '${(budget.used * 100).round()}%',
                style: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.budgetMonth.toUpperCase(),
                style: caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  budgetRemaining(budget),
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: budget.level == BudgetLevel.over ? color : null,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${CurrencyFormatter.format(budget.spent, currency: '₹')} '
                '${AppStrings.budgetOf} '
                '${CurrencyFormatter.format(budget.amount, currency: '₹')}',
                style: caption,
              ),
              if (perDay > 0) ...[
                const SizedBox(height: 6),
                Text(
                  AppStrings.budgetSafePerDay(
                    CurrencyFormatter.format(perDay, currency: '₹'),
                    daysLeft,
                  ),
                  style: caption.copyWith(color: AppColors.success),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Unset extends StatelessWidget {
  const _Unset({required this.spent});

  final double spent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.savings_rounded, color: AppColors.brand),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.budgetSetMonth,
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                spent > 0
                    ? AppStrings.budgetSpentThisMonth(
                        CurrencyFormatter.format(spent, currency: '₹'),
                      )
                    : AppStrings.budgetSetMonthBody,
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary(isDark),
        ),
      ],
    );
  }
}
