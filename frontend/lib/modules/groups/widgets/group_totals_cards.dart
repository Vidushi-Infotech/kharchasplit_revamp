import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/group_totals_calculator.dart';

/// Label for a [TotalsPeriod] (also used by the PDF statement sheet).
String totalsPeriodLabel(TotalsPeriod p) => switch (p) {
  TotalsPeriod.thisMonth => AppStrings.periodThisMonth,
  TotalsPeriod.lastMonth => AppStrings.periodLastMonth,
  TotalsPeriod.thisYear => AppStrings.periodThisYear,
  TotalsPeriod.allTime => AppStrings.periodAllTime,
};

/// This month / Last month / This year / All time.
class GroupTotalsPeriodChips extends StatelessWidget {
  const GroupTotalsPeriodChips({
    super.key,
    required this.selected,
    required this.isDark,
    required this.onSelected,
  });

  final TotalsPeriod selected;
  final bool isDark;
  final ValueChanged<TotalsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in TotalsPeriod.values)
          ChoiceChip(
            label: Text(totalsPeriodLabel(p)),
            selected: p == selected,
            onSelected: (_) => onSelected(p),
            showCheckmark: false,
            selectedColor: AppColors.brand,
            backgroundColor: AppColors.cardBg(isDark),
            side: BorderSide(
              color: p == selected
                  ? AppColors.brand
                  : AppColors.divider(isDark),
            ),
            labelStyle: AppTextStyles.body2(isDark).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: p == selected
                  ? Colors.white
                  : AppColors.textPrimary(isDark),
            ),
          ),
      ],
    );
  }
}

/// Rounded card shell shared by every Totals section.
class GroupTotalsSection extends StatelessWidget {
  const GroupTotalsSection({
    super.key,
    required this.isDark,
    required this.child,
    this.title,
  });

  final bool isDark;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title!,
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// The four headline numbers: group spending, you paid, your share,
/// payments made / received. Two per row on phones, four on wide panes.
class GroupTotalsSummaryCards extends StatelessWidget {
  const GroupTotalsSummaryCards({
    super.key,
    required this.totals,
    required this.currency,
    required this.isDark,
  });

  final GroupTotals totals;
  final String currency;
  final bool isDark;

  String _fmt(double v) => CurrencyFormatter.format(v, currency: currency);

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _SummaryTile(
        label: AppStrings.totalGroupSpending,
        value: _fmt(totals.totalSpending),
        caption: AppStrings.totalsExpenseCount(totals.expenseCount),
        isDark: isDark,
        highlight: true,
      ),
      _SummaryTile(
        label: AppStrings.totalYouPaidFor,
        value: _fmt(totals.youPaid),
        isDark: isDark,
      ),
      _SummaryTile(
        label: AppStrings.yourTotalShare,
        value: _fmt(totals.yourShare),
        isDark: isDark,
      ),
      _SummaryTile(
        label: AppStrings.paymentsMadeReceived,
        value:
            '${_fmt(totals.paymentsMade)} / '
            '${_fmt(totals.paymentsReceived)}',
        isDark: isDark,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 720 ? 4 : 2;
        const gap = 10.0;
        final tileWidth = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles) SizedBox(width: tileWidth, child: t),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.isDark,
    this.caption,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool isDark;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.white : AppColors.textPrimary(isDark);
    final sub = highlight
        ? Colors.white.withValues(alpha: 0.8)
        : AppColors.textSecondary(isDark);
    return Semantics(
      container: true,
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? AppColors.brand : AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(14),
          border: highlight
              ? null
              : Border.all(color: AppColors.divider(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption(isDark).copyWith(color: sub),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.body1(isDark).copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: AppTextStyles.caption(isDark).copyWith(color: sub),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
