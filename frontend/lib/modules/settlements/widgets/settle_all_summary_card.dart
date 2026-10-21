import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/settle_all_controller.dart';

/// Per-group lines ("Goa trip — you owe ₹500" / "Flat — Asha owes you
/// ₹200"), then "Total you pay Asha: ₹300" and the one-line netting
/// explanation. [lines] use the settle-all sign: > 0 = I owe.
class SettleAllSummaryCard extends StatelessWidget {
  const SettleAllSummaryCard({
    super.key,
    required this.lines,
    required this.friendName,
    required this.currency,
  });

  final List<SettleAllLine> lines;
  final String friendName;
  final String currency;

  String _money(double v) =>
      CurrencyFormatter.format(v.abs(), currency: currency);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = settleAllTotal(lines);
    final totalText = AppStrings.totalYouPay(friendName, _money(total));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bounded by the groups you share with one friend — a handful of
          // rows, so a plain Column inside the card is fine.
          for (final l in lines) _LineRow(line: l, text: _lineText(l)),
          Divider(height: 16, color: AppColors.divider(isDark)),
          Semantics(
            liveRegion: true,
            label: totalText,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                totalText,
                style: AppTextStyles.headline3(isDark).copyWith(fontSize: 18),
              ),
            ),
          ),
          if (lines.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                AppStrings.settleAllExplain(lines.length),
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ),
        ],
      ),
    );
  }

  String _lineText(SettleAllLine l) => l.amount > 0
      ? AppStrings.settleAllGroupYouOwe(l.groupName, _money(l.amount))
      : AppStrings.settleAllGroupOwesYou(
          l.groupName,
          friendName,
          _money(l.amount),
        );
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.text});

  final SettleAllLine line;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Red = you owe in this group, green = they owe you.
    final color = line.amount > 0
        ? AppColors.errorText(isDark)
        : AppColors.success;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.group_outlined,
              size: 20,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body2(
                  isDark,
                ).copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Balances changed — check the new total", shown after a 409 until the
/// user taps Record again.
class SettleAllChangedBanner extends StatelessWidget {
  const SettleAllChangedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      liveRegion: true,
      label: AppStrings.balancesChangedCheckTotal,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.balancesChangedCheckTotal,
                style: AppTextStyles.body2(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
