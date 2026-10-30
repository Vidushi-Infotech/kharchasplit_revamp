import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category_model.dart';
import '../../../models/personal_budget_model.dart';
import '../state/personal_budgets_provider.dart';
import '../widgets/budgets/budget_editor_sheet.dart';
import '../widgets/budgets/budget_row.dart';
import '../widgets/budgets/month_budget_card.dart';
import '../widgets/insights/insights_card.dart';

/// Personal mode's Budgets tab: the month's budget, one per category, and
/// the categories spent on without one. Alerts at 80% and 100% come from
/// the add screen (see budget_alerts.dart).
class PersonalBudgetsScreen extends ConsumerWidget {
  const PersonalBudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < Breakpoints.shellTablet ? 20.0 : 32.0;
    final async = ref.watch(personalBudgetsProvider);

    final List<Widget> body = async.when(
      skipLoadingOnReload: true,
      loading: () => const [
        ShimmerList(type: ShimmerListType.expense, itemCount: 4),
      ],
      error: (e, _) => [
        ErrorStateWidget(
          title: AppStrings.budgetLoadError,
          message: e.toString(),
          onRetry: () => ref.read(personalBudgetsProvider.notifier).refresh(),
        ),
      ],
      data: (o) => _sections(context, o),
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(personalBudgetsProvider.notifier).refresh(),
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
                  _Header(
                    isDark: isDark,
                    onAdd: () => BudgetEditorSheet.show(context),
                  ),
                  const SizedBox(height: 16),
                  ...body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, BudgetsOverview o) {
    const gap = SizedBox(height: 14);
    final categories = o.categories;
    final unbudgeted =
        o.spent.entries
            .where((e) => e.value > 0 && o.of(e.key) == null)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return [
      MonthBudgetCard(
        budget: o.total,
        spent: o.totalSpent,
        onTap: () =>
            BudgetEditorSheet.show(context, category: BudgetStatus.total),
      ),
      if (categories.isEmpty && unbudgeted.isEmpty) ...[
        const SizedBox(height: 24),
        EmptyStateWidget(
          icon: '🎯',
          iconSize: 52,
          title: AppStrings.budgetEmptyTitle,
          subtitle: AppStrings.budgetEmptyBody,
          actionLabel: AppStrings.budgetAdd,
          onActionPressed: () => BudgetEditorSheet.show(context),
        ),
      ],
      if (categories.isNotEmpty) ...[
        gap,
        InsightsCard(
          title: AppStrings.budgetCategories,
          child: Column(
            children: [
              for (final b in categories)
                BudgetRow(
                  budget: b,
                  onTap: () =>
                      BudgetEditorSheet.show(context, category: b.category),
                ),
            ],
          ),
        ),
      ],
      if (unbudgeted.isNotEmpty) ...[
        gap,
        InsightsCard(
          title: AppStrings.budgetNotBudgeted,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in unbudgeted)
                _SetBudgetChip(
                  category: e.key,
                  spent: e.value,
                  onTap: () => BudgetEditorSheet.show(context, category: e.key),
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onAdd});

  final bool isDark;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
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
                  AppStrings.budgets,
                  style: AppTextStyles.headline1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: AppStrings.budgetAdd,
          onPressed: onAdd,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.cardBg(isDark),
            side: BorderSide(color: AppColors.divider(isDark)),
          ),
          icon: Icon(Icons.add_rounded, color: AppColors.textPrimary(isDark)),
        ),
      ],
    );
  }
}

/// "Food · ₹3,600 · Set budget" for a category spent on without a budget.
class _SetBudgetChip extends StatelessWidget {
  const _SetBudgetChip({
    required this.category,
    required this.spent,
    required this.onTap,
  });

  final String category;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = CategoryModel.fromId(category)!;
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(cat.icon, size: 16, color: cat.color),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${cat.name} · ${CurrencyFormatter.format(spent, currency: '₹')}',
          ),
          const SizedBox(width: 6),
          const Icon(Icons.add_rounded, size: 16, color: AppColors.brand),
        ],
      ),
      tooltip: AppStrings.budgetSet,
      backgroundColor: AppColors.background(isDark),
      side: BorderSide(color: AppColors.divider(isDark)),
      labelStyle: TextStyle(color: AppColors.textPrimary(isDark)),
    );
  }
}
