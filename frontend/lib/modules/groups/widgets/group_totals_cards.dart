import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../components/list/list_components.dart';
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

/// Flat section shared by every Totals block: a grey title, then the
/// content with the page's side gutter.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

/// The headline numbers as flat label / amount rows: group spending, what
/// you paid, your share, payments made and received, and the change in
/// your balance (tone colored).
class GroupTotalsSummaryRows extends StatelessWidget {
  const GroupTotalsSummaryRows({
    super.key,
    required this.totals,
    required this.currency,
    required this.isDark,
  });

  final GroupTotals totals;
  final String currency;
  final bool isDark;

  String _fmt(double v) =>
      CurrencyFormatter.format(v.abs(), currency: currency);

  @override
  Widget build(BuildContext context) {
    final change = BalanceTone.fromAmount(totals.balanceChange);
    final sign = switch (change) {
      BalanceTone.owed => '+',
      BalanceTone.owe => '−',
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          label: AppStrings.totalGroupSpending,
          caption: AppStrings.totalsExpenseCount(totals.expenseCount),
          value: _fmt(totals.totalSpending),
          isDark: isDark,
          emphasis: true,
        ),
        _SummaryRow(
          label: AppStrings.totalYouPaidFor,
          value: _fmt(totals.youPaid),
          isDark: isDark,
        ),
        _SummaryRow(
          label: AppStrings.yourTotalShare,
          value: _fmt(totals.yourShare),
          isDark: isDark,
        ),
        _SummaryRow(
          label: AppStrings.paymentsMade,
          value: _fmt(totals.paymentsMade),
          isDark: isDark,
        ),
        _SummaryRow(
          label: AppStrings.paymentsReceived,
          value: _fmt(totals.paymentsReceived),
          isDark: isDark,
        ),
        _SummaryRow(
          label: AppStrings.totalChangeInBalance,
          value: '$sign${_fmt(totals.balanceChange)}',
          valueColor: change.color(isDark),
          isDark: isDark,
          showDivider: false,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.caption,
    this.valueColor,
    this.emphasis = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final bool isDark;
  final bool emphasis;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.divider(isDark),
                    width: 0.6,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: (emphasis ? textTheme.titleLarge : textTheme.titleMedium)
                  ?.copyWith(
                    color: valueColor ?? AppColors.textPrimary(isDark),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
