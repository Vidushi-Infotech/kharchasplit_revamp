import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/personal_summary_model.dart';
import 'insights_card.dart';

/// Spending on each day of the month as bars, with the daily average
/// (over the days so far, for the current month) in the corner. Touch a
/// bar for that day's amount.
class DailySpendChart extends StatelessWidget {
  const DailySpendChart({super.key, required this.summary});

  final PersonalSummary summary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = summary.daily;
    final now = DateTime.now();
    final isCurrent =
        summary.month.year == now.year && summary.month.month == now.month;
    final counted = isCurrent ? now.day : days.length;
    final average = counted > 0 ? summary.spent / counted : 0.0;
    final peak = days.fold<double>(0, (m, d) => d.spent > m ? d.spent : m);
    final label = AppColors.textSecondary(isDark);

    return InsightsCard(
      title: AppStrings.insightsDaily,
      note:
          '${AppStrings.insightsAverage} ${CurrencyFormatter.compact(average)}'
          '${AppStrings.insightsPerDay}',
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            maxY: peak == 0 ? 1 : peak * 1.15,
            alignment: BarChartAlignment.spaceBetween,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: peak == 0 ? 1 : peak / 2,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.divider(isDark), strokeWidth: 0.6),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (average > 0)
                  HorizontalLine(
                    y: average,
                    color: AppColors.brand.withValues(alpha: 0.7),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
              ],
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final day = value.toInt() + 1;
                    final show =
                        day == 1 ||
                        day % 7 == 1 && day < 29 ||
                        day == days.length;
                    if (!show) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        '$day',
                        style: TextStyle(color: label, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.surface(isDark),
                tooltipBorder: BorderSide(color: AppColors.divider(isDark)),
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${DateFormat('d MMM').format(days[group.x].day)}\n',
                  TextStyle(color: label, fontSize: 11),
                  children: [
                    TextSpan(
                      text: CurrencyFormatter.format(rod.toY, currency: '₹'),
                      style: TextStyle(
                        color: AppColors.textPrimary(isDark),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < days.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: days[i].spent,
                      width: 5,
                      color: days[i].spent > average * 2 && average > 0
                          ? AppColors.warning
                          : AppColors.brand,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
