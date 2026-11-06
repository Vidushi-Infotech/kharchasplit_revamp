import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/personal_expenses_provider.dart';

/// This month's money in, money out and what's left (Net), side by side,
/// on the Personal home.
class CashFlowCard extends StatelessWidget {
  const CashFlowCard({super.key, required this.flow, this.onAddIncome});

  final CashFlow flow;

  /// Shown as a small "+ Income" action while nothing came in this month.
  final VoidCallback? onAddIncome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final month = DateFormat('MMMM').format(DateTime.now());
    final positive = flow.net >= 0;
    return Semantics(
      label:
          '${AppStrings.thisMonth}: ${AppStrings.moneyIn} ${_money(flow.income)}, '
          '${AppStrings.moneyOut} ${_money(flow.spent)}, '
          '${AppStrings.net} ${_signed(flow.net)}',
      excludeSemantics: onAddIncome == null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    month.toUpperCase(),
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (onAddIncome != null)
                  TextButton.icon(
                    onPressed: onAddIncome,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(AppStrings.personalIncome),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Figure(
                  label: AppStrings.moneyIn,
                  value: _money(flow.income),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.success,
                ),
                _Figure(
                  label: AppStrings.moneyOut,
                  value: _money(flow.spent),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.warning,
                ),
                _Figure(
                  label: AppStrings.net,
                  value: _signed(flow.net),
                  icon: positive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: positive
                      ? AppColors.success
                      : AppColors.errorText(isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _money(double v) => CurrencyFormatter.format(v, currency: '₹');

  static String _signed(double v) => '${v < 0 ? '-' : '+'}${_money(v.abs())}';
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.body1(isDark).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
