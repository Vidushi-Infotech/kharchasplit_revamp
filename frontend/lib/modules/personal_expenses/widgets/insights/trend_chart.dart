import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/personal_summary_model.dart';
import 'insights_card.dart';

/// The last six months side by side: money in (green) next to money out
/// (orange). Income bars only show when there was any income.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.summary});

  final PersonalSummary summary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final months = summary.trend;
    final withIncome = months.any((m) => m.income > 0);
    final peak = months.fold<double>(
      0,
      (m, t) => [
        m,
        t.spent,
        if (withIncome) t.income,
      ].reduce((a, b) => a > b ? a : b),
    );
    final label = AppColors.textSecondary(isDark);

    return InsightsCard(
      title: AppStrings.insightsSixMonths,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withIncome)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  _Key(color: AppColors.success, text: AppStrings.moneyIn),
                  const SizedBox(width: 14),
                  _Key(color: AppColors.warning, text: AppStrings.moneyOut),
                ],
              ),
            ),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: peak == 0 ? 1 : peak * 1.15,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          DateFormat('MMM').format(months[value.toInt()].month),
                          style: TextStyle(
                            color: value.toInt() == months.length - 1
                                ? AppColors.textPrimary(isDark)
                                : label,
                            fontSize: 11,
                            fontWeight: value.toInt() == months.length - 1
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface(isDark),
                    tooltipBorder: BorderSide(color: AppColors.divider(isDark)),
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      CurrencyFormatter.format(rod.toY, currency: '₹'),
                      TextStyle(
                        color: rod.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < months.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        if (withIncome)
                          _rod(months[i].income, AppColors.success),
                        _rod(months[i].spent, AppColors.warning),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static BarChartRodData _rod(double y, Color color) => BarChartRodData(
    toY: y,
    width: 12,
    color: color,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.caption(
            isDark,
          ).copyWith(color: AppColors.textSecondary(isDark)),
        ),
      ],
    );
  }
}
