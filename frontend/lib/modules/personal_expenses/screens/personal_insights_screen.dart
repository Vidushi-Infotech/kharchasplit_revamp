import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category_model.dart';
import '../../../models/personal_summary_model.dart';
import '../state/personal_insights_provider.dart';
import '../widgets/insights/category_breakdown_card.dart';
import '../widgets/insights/daily_spend_chart.dart';
import '../widgets/insights/insights_card.dart';
import '../widgets/insights/month_switcher.dart';
import '../widgets/insights/spend_overview_card.dart';
import '../widgets/insights/trend_chart.dart';

/// Personal mode's Insights tab: one month at a time, where the money went
/// (by category and by day), against last month and the last six months.
class PersonalInsightsScreen extends ConsumerWidget {
  const PersonalInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final month = ref.watch(insightsMonthProvider);
    final summary = ref.watch(personalSummaryProvider);
    final gutter = width < Breakpoints.shellTablet ? 20.0 : 32.0;

    final List<Widget> body = summary.when(
      // Keep the shown month's cards while the next one loads.
      skipLoadingOnReload: true,
      // ShimmerList scrolls itself, so it needs a height inside this list.
      loading: () => const [
        SizedBox(
          height: 360,
          child: ShimmerList(type: ShimmerListType.expense, itemCount: 4),
        ),
      ],
      error: (e, _) => [
        ErrorStateWidget(
          title: AppStrings.insightsLoadError,
          message: e.toString(),
          onRetry: () => ref.invalidate(personalSummaryProvider),
        ),
      ],
      data: (s) => _cards(context, s),
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(personalSummaryProvider.future),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width < 1100 ? 720 : 900),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  18,
                  gutter,
                  bottomNavReserve(context.widthTier, compact: 120),
                ),
                children: [
                  _Header(isDark: isDark),
                  const SizedBox(height: 14),
                  MonthSwitcher(
                    month: month,
                    onChanged: (m) =>
                        ref.read(insightsMonthProvider.notifier).state = m,
                  ),
                  const SizedBox(height: 14),
                  ...body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _cards(BuildContext context, PersonalSummary s) {
    const gap = SizedBox(height: 14);
    final hasHistory = s.trend.any((m) => m.spent > 0 || m.income > 0);
    if (s.isEmpty) {
      return [
        EmptyStateWidget(
          icon: '📊',
          iconSize: 56,
          title: AppStrings.insightsEmptyTitle,
          subtitle: AppStrings.insightsEmptyBody,
          actionLabel: AppStrings.addPersonalExpense,
          onActionPressed: () => context.push('/home/personal/new'),
        ),
        if (hasHistory) ...[gap, TrendChart(summary: s)],
      ];
    }
    return [
      SpendOverviewCard(summary: s),
      if (s.categories.isNotEmpty) ...[gap, CategoryBreakdownCard(summary: s)],
      if (s.spent > 0) ...[gap, DailySpendChart(summary: s)],
      if (s.incomeCategories.isNotEmpty) ...[gap, _IncomeSources(summary: s)],
      gap,
      TrendChart(summary: s),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.personal.toUpperCase(),
          style: AppTextStyles.caption(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            AppStrings.insights,
            style: AppTextStyles.headline1(isDark).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Where the month's income came from, one row per source.
class _IncomeSources extends StatelessWidget {
  const _IncomeSources({required this.summary});

  final PersonalSummary summary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InsightsCard(
      title: AppStrings.insightsIncomeFrom,
      child: Column(
        children: [
          for (final c in summary.incomeCategories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    CategoryModel.fromId(c.category)!.icon,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      CategoryModel.fromId(c.category)!.name,
                      style: AppTextStyles.body1(isDark).copyWith(fontSize: 14),
                    ),
                  ),
                  Text(
                    '+${CurrencyFormatter.format(c.amount, currency: '₹')}',
                    style: AppTextStyles.body1(isDark).copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
