import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';
import 'balance_tone.dart';

/// Trailing block on list rows: a small label with the amount under it,
/// both in the tone's color ("you lent" / "₹150.00"). Settled and
/// not-involved rows show only the label.
class BalanceAmountLabel extends StatelessWidget {
  const BalanceAmountLabel({
    super.key,
    required this.tone,
    required this.amount,
    this.currency = '₹',
    this.forExpense = false,
    this.label,
  });

  final BalanceTone tone;

  /// Shown as an absolute value; the tone carries the direction.
  final double amount;
  final String currency;

  /// Expense rows say "you lent / you borrowed"; group and friend rows say
  /// "you are owed / you owe".
  final bool forExpense;

  /// Overrides the tone's label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = tone.color(isDark);
    final text =
        label ?? (forExpense ? tone.expenseLabel : tone.balanceLabel);
    final showAmount =
        tone == BalanceTone.owed || tone == BalanceTone.owe;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: showAmount
          ? '$text ${CurrencyFormatter.format(amount.abs(), currency: currency)}'
          : text,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            text,
            style: textTheme.labelSmall?.copyWith(color: color, height: 1.2),
          ),
          if (showAmount)
            Text(
              CurrencyFormatter.format(amount.abs(), currency: currency),
              style: textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
        ],
      ),
    );
  }
}
