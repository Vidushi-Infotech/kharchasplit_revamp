import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/group_totals_calculator.dart';

/// Name for a member row; invited people may not have a name yet.
String totalsMemberName(MemberTotal member, {required bool isMe}) {
  final name = member.name.trim().isEmpty
      ? AppStrings.invitedMember
      : member.name.trim();
  return isMe ? '$name (${AppStrings.totalsYou})' : name;
}

/// Gray line under the name: "Paid ₹1,900.00 · Share ₹950.00".
String totalsMemberLine(MemberTotal member, String currency) =>
    AppStrings.totalsPaidShareLine(
      CurrencyFormatter.format(member.paid, currency: currency),
      CurrencyFormatter.format(member.share, currency: currency),
    );

/// Trailing label for paid − share: "gets back" / "owes" / "settled up".
String totalsMemberLabel(BalanceTone tone) => switch (tone) {
      BalanceTone.owed => AppStrings.memberGetsBack,
      BalanceTone.owe => AppStrings.memberOwes,
      _ => AppStrings.settledUpLower,
    };

/// "Paid vs share" section title. The rows are [GroupTotalsMemberRow]s
/// built lazily by the tab's ListView.
class GroupTotalsMembersHeader extends StatelessWidget {
  const GroupTotalsMembersHeader({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        AppStrings.totalsPaidVsShare,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// One member as a flat row: avatar, name, "Paid ₹X · Share ₹Y", and on
/// the right what paid − share comes to ("gets back ₹950.00" in green,
/// "owes ₹600.00" in orange).
class GroupTotalsMemberRow extends StatelessWidget {
  const GroupTotalsMemberRow({
    super.key,
    required this.member,
    required this.currency,
    required this.isDark,
    required this.isMe,
    this.showDivider = true,
  });

  final MemberTotal member;
  final String currency;
  final bool isDark;
  final bool isMe;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tone = BalanceTone.fromAmount(member.net);
    final label = totalsMemberLabel(tone);
    final name = totalsMemberName(member, isMe: isMe);
    final line = totalsMemberLine(member, currency);
    final amount = CurrencyFormatter.format(
      member.net.abs(),
      currency: currency,
    );
    return KsListRow(
      dense: true,
      showDivider: showDivider,
      leading: AvatarWidget(
        name: totalsMemberName(member, isMe: false),
        radius: 20,
      ),
      title: name,
      subtitles: [line],
      trailing: BalanceAmountLabel(
        tone: tone,
        amount: member.net,
        currency: currency,
        label: label,
      ),
      semanticsLabel: '$name, $line, $label'
          '${tone == BalanceTone.settled ? '' : ' $amount'}',
    );
  }
}
