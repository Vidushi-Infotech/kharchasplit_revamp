import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/reports_provider.dart';

class CategoryChartWidget extends StatelessWidget {
  final ReportsData report;

  const CategoryChartWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive spacing
    final isLarge = screenWidth > 1100;
    final margin = isLarge ? const EdgeInsets.only(right: 12) : const EdgeInsets.all(16);
    final padding = isLarge ? const EdgeInsets.all(12) : const EdgeInsets.all(16);

    return Semantics(
      label: 'Spending by category pie chart',
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
              'Spending by Category',
              style: AppTextStyles.headline3(isDark).copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(report.categorySpending, isDark),
                  centerSpaceRadius: 35,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> categorySpending,
    bool isDark,
  ) {
    final colors = [
      AppColors.brand,
      AppColors.success,
      AppColors.warning,
      Colors.purple,
      Colors.orange,
    ];

    return categorySpending.entries.toList().asMap().entries.map((e) {
      final index = e.key;
      final amount = e.value.value;
      final total = categorySpending.values.fold<double>(0, (a, b) => a + b);
      final percentage = (amount / total * 100);

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: AppTextStyles.caption(isDark).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }
}
