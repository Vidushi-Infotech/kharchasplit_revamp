import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/reports_provider.dart';

class MonthlyChartWidget extends StatelessWidget {
  final ReportsData report;

  const MonthlyChartWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive spacing
    final isLarge = screenWidth > 1100;
    final margin = isLarge ? const EdgeInsets.only(left: 12) : const EdgeInsets.all(16);
    final padding = isLarge ? const EdgeInsets.all(12) : const EdgeInsets.all(16);

    return Semantics(
      label: 'Monthly spending trend bar chart',
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Spending Trend',
              style: AppTextStyles.headline3(isDark).copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: _buildBarGroups(report.monthlySpending),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5000,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.divider(Theme.of(context).brightness == Brightness.dark)
                            .withValues(alpha: 0.3),
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final months = report.monthlySpending.keys.toList();
                          if (value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                months[value.toInt()],
                                style: AppTextStyles.body2(
                                    Theme.of(context).brightness == Brightness.dark)
                                    .copyWith(fontSize: 12),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          if (value % 5000 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                '₹${(value / 1000).toStringAsFixed(0)}K',
                                style: AppTextStyles.caption(
                                    Theme.of(context).brightness == Brightness.dark)
                                    .copyWith(fontSize: 11),
                                textAlign: TextAlign.right,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, double> monthlySpending) {
    return monthlySpending.entries.toList().asMap().entries.map((e) {
      final index = e.key;
      final amount = e.value.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: amount,
            color: AppColors.brand,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }
}
