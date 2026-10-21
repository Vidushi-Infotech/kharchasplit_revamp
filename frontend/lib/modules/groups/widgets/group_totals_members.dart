import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/group_totals_calculator.dart';

/// Column titles for the per-member "Paid vs share" table. The rows are
/// [GroupTotalsMemberRow]s built lazily by the tab's ListView.
class GroupTotalsMembersHeader extends StatelessWidget {
  const GroupTotalsMembersHeader({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.caption(isDark).copyWith(
      color: AppColors.textSecondary(isDark),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              AppStrings.totalsPaidVsShare,
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Row(
              children: [
                const Expanded(flex: 4, child: SizedBox.shrink()),
                Expanded(
                  flex: 3,
                  child: Text(
                    AppStrings.totalsPaid.toUpperCase(),
                    style: style,
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    AppStrings.totalsShare.toUpperCase(),
                    style: style,
                    textAlign: TextAlign.end,
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

/// One member: what they paid vs their share in the period, with the
/// difference underneath (green = paid more than their share).
class GroupTotalsMemberRow extends StatelessWidget {
  const GroupTotalsMemberRow({
    super.key,
    required this.member,
    required this.currency,
    required this.isDark,
    required this.isMe,
  });

  final MemberTotal member;
  final String currency;
  final bool isDark;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    String fmt(double v) => CurrencyFormatter.format(v, currency: currency);
    final net = member.net;
    final netColor = net.abs() < 0.005
        ? AppColors.textSecondary(isDark)
        : net > 0
        ? AppColors.tealLight
        : AppColors.errorText(isDark);
    final name = isMe
        ? '${member.name} (${AppStrings.totalsYou})'
        : member.name;
    final numberStyle = AppTextStyles.body2(
      isDark,
    ).copyWith(fontWeight: FontWeight.w600);
    return Semantics(
      label:
          '$name: ${AppStrings.totalsPaid} ${fmt(member.paid)}, '
          '${AppStrings.totalsShare} ${fmt(member.share)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body2(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    net.abs() < 0.005
                        ? fmt(0)
                        : CurrencyFormatter.format(
                            net,
                            currency: currency,
                            showSign: true,
                          ),
                    style: AppTextStyles.caption(
                      isDark,
                    ).copyWith(color: netColor),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                fmt(member.paid),
                style: numberStyle,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                fmt(member.share),
                style: numberStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
