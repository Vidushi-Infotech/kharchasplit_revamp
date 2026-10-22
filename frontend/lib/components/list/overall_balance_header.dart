import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import 'balance_tone.dart';

/// "Overall, you are owed ₹200.00" line at the top of Groups and Friends,
/// with an optional trailing action (the filter button).
class OverallBalanceHeader extends StatelessWidget {
  const OverallBalanceHeader({
    super.key,
    required this.net,
    this.currency = '₹',
    this.trailing,
    this.onTap,
  });

  /// Positive = you are owed overall, negative = you owe.
  final double net;
  final String currency;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = BalanceTone.fromAmount(net);
    final amount = CurrencyFormatter.format(net.abs(), currency: currency);
    final text = switch (tone) {
      BalanceTone.owed => AppStrings.overallYouAreOwed(amount),
      BalanceTone.owe => AppStrings.overallYouOwe(amount),
      _ => AppStrings.youAreAllSettledUp,
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tone.color(isDark),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
