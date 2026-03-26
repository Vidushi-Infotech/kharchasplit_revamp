import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../components/components.dart';
import '../state/reports_provider.dart';
import '../widgets/period_selector_widget.dart';
import '../widgets/stats_summary_widget.dart';
import '../widgets/category_chart_widget.dart';
import '../widgets/monthly_chart_widget.dart';
import '../widgets/top_categories_widget.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final reportAsync = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Semantics(
          label: 'Reports page',
          child: const Text('Reports'),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: reportAsync.when(
          loading: () => const ShimmerList(type: ShimmerListType.expense),
          error: (err, stack) => ErrorStateWidget(
            title: 'Failed to load reports',
            message: 'Unable to fetch report data. Please try again.',
            onRetry: () {
              // Trigger refresh
            },
          ),
          data: (report) {
            if (screenWidth < 600) {
              return _buildCompactLayout(context, isDark, report);
            } else if (screenWidth < 1100) {
              return _buildStandardLayout(context, isDark, report);
            } else {
              return _buildLargeLayout(context, isDark, report);
            }
          },
        ),
      ),
    );
  }

  // Compact: <600px - Mobile layout (16-20px padding)
  Widget _buildCompactLayout(BuildContext context, bool isDark, ReportsData report) {
    return SingleChildScrollView(
      child: Column(
        children: [
          PeriodSelectorWidget(),
          StatsSummaryWidget(report: report),
          const SizedBox(height: 12),
          CategoryChartWidget(report: report),
          const SizedBox(height: 12),
          MonthlyChartWidget(report: report),
          const SizedBox(height: 12),
          TopCategoriesWidget(report: report),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Standard: 600-1100px - Tablet layout (24-32px padding)
  Widget _buildStandardLayout(BuildContext context, bool isDark, ReportsData report) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                PeriodSelectorWidget(),
                const SizedBox(height: 16),
                StatsSummaryWidget(report: report),
                const SizedBox(height: 20),
                // Charts side by side
                Row(
                  children: [
                    Expanded(
                      child: CategoryChartWidget(report: report),
                    ),
                    Expanded(
                      child: MonthlyChartWidget(report: report),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TopCategoriesWidget(report: report),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Large: >1100px - Desktop layout (32-48px padding)
  Widget _buildLargeLayout(BuildContext context, bool isDark, ReportsData report) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1600),
            child: Column(
              children: [
                // Period Selector (full width)
                PeriodSelectorWidget(),
                const SizedBox(height: 16),
                // Stats Cards (full width, 3 columns)
                StatsSummaryWidget(report: report),
                const SizedBox(height: 16),
                // Charts + Categories (3 column grid)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Category Chart
                    Expanded(
                      flex: 1,
                      child: CategoryChartWidget(report: report),
                    ),
                    // Center: Monthly Chart
                    Expanded(
                      flex: 1,
                      child: MonthlyChartWidget(report: report),
                    ),
                    // Right: Top Categories
                    Expanded(
                      flex: 1,
                      child: TopCategoriesWidget(report: report),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
