import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../components/web/web_page.dart';
import '../../../components/web/web_page_header.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../components/components.dart';
import '../state/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final reportAsync = ref.watch(reportsProvider);
    final period = ref.watch(reportsPeriodProvider);

    final isWeb = context.widthTier.isWebTier;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      // The web shell supplies navigation and the page header, so the mobile
      // title bar would just be a second, emptier one.
      appBar: isWeb
          ? null
          : AppBar(
              title: const Text('Reports'),
              elevation: 0,
              backgroundColor: AppColors.surface(isDark),
            ),
      body: reportAsync.when(
        loading: () => const ShimmerList(type: ShimmerListType.expense),
        error: (err, stack) => ErrorStateWidget(
          title: 'Failed to load reports',
          message: 'Unable to fetch report data. Please try again.',
          onRetry: () => ref.invalidate(reportsProvider),
        ),
        data: (report) {
          final body = screenWidth < 600
              ? _buildCompactLayout(context, isDark, report, period, ref)
              : screenWidth < 1100
              ? _buildStandardLayout(context, isDark, report, period, ref)
              : _buildLargeLayout(context, isDark, report, period, ref);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(reportsProvider);
              await ref.read(reportsProvider.future);
            },
            child: body,
          );
        },
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    ReportsData report,
    ReportsPeriod period,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildPeriodSelector(context, isDark, period, ref),
          _buildStatsSummary(context, isDark, report),
          _buildCategoryChart(context, isDark, report),
          _buildMonthlyChart(context, isDark, report),
          _buildTopCategories(context, isDark, report),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    ReportsData report,
    ReportsPeriod period,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPeriodSelector(context, isDark, period, ref),
          _buildStatsSummary(context, isDark, report),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(child: _buildCategoryChart(context, isDark, report)),
                const SizedBox(width: 16),
                Expanded(child: _buildMonthlyChart(context, isDark, report)),
              ],
            ),
          ),
          _buildTopCategories(context, isDark, report),
        ],
      ),
    );
  }

  /// Desktop layout.
  ///
  /// The previous version used three side-by-side scroll views, each centring
  /// its own content vertically — which left the cards floating in the middle
  /// of a mostly empty column. This is one scroll, capped and centred, with
  /// the charts in a grid that reads top-to-bottom like a report.
  Widget _buildLargeLayout(
    BuildContext context,
    bool isDark,
    ReportsData report,
    ReportsPeriod period,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: WebContentColumn(
        width: ContentWidth.wide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            WebPageHeader(
              title: 'Reports',
              subtitle: 'Where your money went, and who it went to.',
              actions: [_buildPeriodSelector(context, isDark, period, ref)],
            ),
            const SizedBox(height: 24),
            _buildStatsSummary(context, isDark, report),
            const SizedBox(height: 8),
            // Charts sit two-up on a wide display and stack below that, so
            // neither one gets squeezed into an unreadable strip.
            LayoutBuilder(
              builder: (context, constraints) {
                final twoUp = constraints.maxWidth >= 900;
                final category = _buildCategoryChart(context, isDark, report);
                final monthly = _buildMonthlyChart(context, isDark, report);
                if (!twoUp) {
                  return Column(children: [category, monthly]);
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: category),
                      Expanded(child: monthly),
                    ],
                  ),
                );
              },
            ),
            _buildTopCategories(context, isDark, report),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    bool isDark,
    ReportsPeriod period,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPeriodChip(
            context,
            isDark,
            'Month',
            ReportsPeriod.month,
            period,
            ref,
          ),
          _buildPeriodChip(
            context,
            isDark,
            'Quarter',
            ReportsPeriod.quarter,
            period,
            ref,
          ),
          _buildPeriodChip(
            context,
            isDark,
            'Year',
            ReportsPeriod.year,
            period,
            ref,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(
    BuildContext context,
    bool isDark,
    String label,
    ReportsPeriod value,
    ReportsPeriod selected,
    WidgetRef ref,
  ) {
    final isSelected = value == selected;

    return GestureDetector(
      onTap: () => ref.read(reportsPeriodProvider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.divider(isDark),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2(isDark).copyWith(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textPrimary(isDark),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary(
    BuildContext context,
    bool isDark,
    ReportsData report,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildStatCard(
            context,
            isDark,
            'Total Spending',
            report.totalSpending,
            AppColors.brand,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  isDark,
                  'You Owe',
                  report.totalYouOwe,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  context,
                  isDark,
                  'Owed to You',
                  report.totalOwed,
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    bool isDark,
    String label,
    double amount,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption(isDark)),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount),
            style: AppTextStyles.headline3(
              isDark,
            ).copyWith(color: color, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(
    BuildContext context,
    bool isDark,
    ReportsData report,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending by Category',
            style: AppTextStyles.headline3(isDark).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _buildPieChartSections(
                  report.categorySpending,
                  isDark,
                ),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
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
      final category = e.value.key;
      final amount = e.value.value;
      final total = categorySpending.values.fold<double>(0, (a, b) => a + b);
      final percentage = (amount / total * 100);

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: AppTextStyles.caption(
          isDark,
        ).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      );
    }).toList();
  }

  Widget _buildMonthlyChart(
    BuildContext context,
    bool isDark,
    ReportsData report,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Spending Trend',
            style: AppTextStyles.headline3(isDark).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: _buildBarGroups(report.monthlySpending),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = report.monthlySpending.keys.toList();
                        if (value.toInt() < months.length) {
                          return Text(months[value.toInt()]);
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('₹${(value / 1000).toStringAsFixed(0)}K');
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildTopCategories(
    BuildContext context,
    bool isDark,
    ReportsData report,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Categories',
            style: AppTextStyles.headline3(isDark).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          ...report.topCategories.map((category) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(category.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.category,
                          style: AppTextStyles.body2(isDark),
                        ),
                        Container(
                          height: 4,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: AppColors.divider(isDark),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: report.totalSpending > 0
                                ? (category.amount / report.totalSpending)
                                      .clamp(0.0, 1.0)
                                : 0,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.compact(category.amount),
                    style: AppTextStyles.body2(
                      isDark,
                    ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
