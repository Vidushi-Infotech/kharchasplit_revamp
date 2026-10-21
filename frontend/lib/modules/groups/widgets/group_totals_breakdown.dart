import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/group_totals_calculator.dart';
import 'group_totals_cards.dart';

Color _categoryColor(String hex) {
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? AppColors.gray : Color(0xFF000000 | v);
}

/// Spending per category as horizontal bars with the % of the total.
/// At most a dozen categories exist, so a plain column is fine here.
class GroupTotalsCategorySection extends StatelessWidget {
  const GroupTotalsCategorySection({
    super.key,
    required this.categories,
    required this.currency,
    required this.isDark,
  });

  final List<CategoryTotal> categories;
  final String currency;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GroupTotalsSection(
      isDark: isDark,
      title: AppStrings.totalsByCategory,
      child: Column(children: [for (final c in categories) _categoryRow(c)]),
    );
  }

  Widget _categoryRow(CategoryTotal c) {
    final color = _categoryColor(c.category.colorHex);
    final pct = (c.fraction * 100).round();
    final amount = CurrencyFormatter.format(c.amount, currency: currency);
    return Semantics(
      label: '${c.category.name}: $amount, $pct percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(c.category.icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.category.name,
                    style: AppTextStyles.body2(isDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$amount · $pct%',
                  style: AppTextStyles.body2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.fraction.clamp(0.0, 1.0),
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.divider(
                  isDark,
                ).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spending per month as vertical bars (up to 12, zero months included).
class GroupTotalsMonthSection extends StatelessWidget {
  const GroupTotalsMonthSection({
    super.key,
    required this.months,
    required this.currency,
    required this.isDark,
  });

  final List<MonthTotal> months;
  final String currency;
  final bool isDark;

  static const double _barArea = 120;

  @override
  Widget build(BuildContext context) {
    final max = months.fold<double>(0, (m, e) => e.amount > m ? e.amount : m);
    final spansYears = months.first.month.year != months.last.month.year;
    final label = DateFormat(spansYears ? 'MMM yy' : 'MMM');
    return GroupTotalsSection(
      isDark: isDark,
      title: AppStrings.totalsByMonth,
      child: SizedBox(
        height: _barArea + 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final m in months)
              Expanded(
                child: _MonthBar(
                  label: label.format(m.month),
                  amount: m.amount,
                  fraction: max > 0 ? m.amount / max : 0,
                  currency: currency,
                  isDark: isDark,
                  barArea: _barArea,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.currency,
    required this.isDark,
    required this.barArea,
  });

  final String label;
  final double amount;
  final double fraction;
  final String currency;
  final bool isDark;
  final double barArea;

  @override
  Widget build(BuildContext context) {
    final formatted = CurrencyFormatter.format(amount, currency: currency);
    return Semantics(
      label: '$label: $formatted',
      excludeSemantics: true,
      child: Tooltip(
        message: '$label · $formatted',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                // A sliver of bar for empty months so the axis reads.
                height: (barArea * fraction).clamp(2.0, barArea),
                decoration: BoxDecoration(
                  color: amount > 0
                      ? AppColors.brand
                      : AppColors.divider(isDark),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
