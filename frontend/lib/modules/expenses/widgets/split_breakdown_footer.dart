import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

/// Footer of [SplitBreakdownWidget]: the total assigned for the split type
/// and, for Unequally (exact), the remaining / over-by line plus a hint.
class SplitBreakdownFooter extends StatelessWidget {
  const SplitBreakdownFooter({
    super.key,
    required this.splitType,
    required this.totalAmount,
    required this.total,
    this.currency = '₹',
  });

  /// Symbol the amounts are in (the form's entry currency).
  final String currency;

  final SplitType splitType;
  final double totalAmount;

  /// Sum of the included members' entered values.
  final double total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String totalLabel;
    String totalValue;
    switch (splitType) {
      case SplitType.percentage:
        totalLabel = 'Total assigned';
        totalValue = '${total.toStringAsFixed(1)}% / 100%';
        break;
      case SplitType.shares:
        totalLabel = 'Total shares';
        totalValue = '${total.toStringAsFixed(0)} shares';
        break;
      case SplitType.exact:
        final pct = totalAmount > 0 ? (total / totalAmount * 100) : 0.0;
        totalLabel = 'Total assigned';
        totalValue =
            '$currency${total.toStringAsFixed(2)}  ·  ${pct.toStringAsFixed(1)}%';
        break;
      case SplitType.equal:
        totalLabel = 'Total Included';
        totalValue = '$currency${total.toStringAsFixed(2)}';
        break;
    }

    final children = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(totalLabel, style: AppTextStyles.body2(isDark)),
          Text(
            totalValue,
            style: AppTextStyles.body2(
              isDark,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ];

    // For Unequally (Exact) — show the remaining-to-assign line + a helper.
    if (splitType == SplitType.exact) {
      final remaining = totalAmount - total;
      Color rowColor;
      String rowLabel;
      String rowValue;
      if (remaining.abs() < 0.01) {
        rowColor = AppColors.success;
        rowLabel = '✓ Balanced';
        rowValue = '${currency}0.00';
      } else if (remaining > 0) {
        rowColor = AppColors.warning;
        rowLabel = '⚠️ Remaining to assign';
        rowValue = '$currency${remaining.toStringAsFixed(2)}';
      } else {
        rowColor = AppColors.warning;
        rowLabel = '⚠️ Over by';
        rowValue = '$currency${(-remaining).toStringAsFixed(2)}';
      }

      children.addAll([
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              rowLabel,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: rowColor, fontWeight: FontWeight.w600),
            ),
            Text(
              rowValue,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: rowColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 14,
                color: AppColors.brand,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Manually assign each amount. Sum must equal $currency${totalAmount.toStringAsFixed(2)}.',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
