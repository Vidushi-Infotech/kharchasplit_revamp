import 'package:flutter/material.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../state/group_detail_provider.dart';
import '../state/group_display.dart';
import '../state/group_member_balances.dart';

/// Most per-person lines under the overall balance before "Plus N more".
const int _maxLines = 3;

/// Group name, the viewer's overall balance in the group (tone colored)
/// and up to three "Test F. owes you ₹200.00" lines, under the banner.
class GroupDetailSummary extends StatelessWidget {
  const GroupDetailSummary({
    super.key,
    required this.detail,
    required this.myId,
    this.onBalancesTap,
    this.horizontalPadding = 16,
  });

  final GroupDetail detail;
  final String? myId;

  /// Tapping the balance lines opens Balances.
  final VoidCallback? onBalancesTap;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final currency = detail.group.currency;
    final summary = buildViewerSummary(detail, myId);
    final tone = BalanceTone.fromAmount(summary.net);
    final net = CurrencyFormatter.format(summary.net.abs(), currency: currency);
    final overall = switch (tone) {
      BalanceTone.owed => AppStrings.groupOverallOwed(net),
      BalanceTone.owe => AppStrings.groupOverallOwe(net),
      _ => AppStrings.groupAllSettled,
    };
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary(isDark),
      height: 1.35,
    );
    final shown = summary.lines.take(_maxLines).toList();
    final more = summary.lines.length - shown.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              detail.group.displayTitle(myId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (detail.group.isDirect)
            Text(AppStrings.nonGroupExpenses, style: secondary),
          const SizedBox(height: 6),
          InkWell(
            onTap: onBalancesTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overall,
                    style: textTheme.titleMedium?.copyWith(
                      color: tone.color(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final line in shown)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(_lineText(line, currency), style: secondary),
                    ),
                  if (more > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        AppStrings.plusMoreBalances(more),
                        style: secondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lineText(MemberBalanceLine line, String currency) {
    final amount = CurrencyFormatter.format(
      line.amount.abs(),
      currency: currency,
    );
    final name = line.other.name.trim().isEmpty
        ? AppStrings.formerMember
        : NameFormat.short(line.other.name);
    return line.amount > 0
        ? AppStrings.nameOwesYou(name, amount)
        : AppStrings.youOweName(name, amount);
  }
}
