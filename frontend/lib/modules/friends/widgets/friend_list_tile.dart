import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friend_lines.dart';
import '../state/friends_provider.dart';
import 'friend_balance_label.dart';

/// One flat row of the Friends list: round avatar, name (+ "Invited" for
/// placeholder users), gray per-group lines, and "owes you / you owe /
/// settled up" on the right.
class FriendListTile extends StatelessWidget {
  const FriendListTile({
    super.key,
    required this.friend,
    required this.onTap,
    this.showDivider = true,
  });

  final FriendBalance friend;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = friend.user;
    final lines = friendBalanceLines(friend);
    final byCurrency = friend.netByCurrency;

    // Mixed currencies are never converted: one line per currency.
    final Widget trailing;
    if (byCurrency.length > 1) {
      trailing = FriendBalanceLabel(friend: friend);
    } else {
      final entry = byCurrency.entries.firstOrNull;
      final tone = BalanceTone.fromAmount(entry?.value ?? 0);
      trailing = BalanceAmountLabel(
        tone: tone,
        amount: entry?.value ?? 0,
        currency: entry?.key ?? 'INR',
        label: tone == BalanceTone.owed ? AppStrings.owesYou : null,
      );
    }

    return KsListRow(
      leading: AvatarWidget(
        imageUrl: user.avatarUrl,
        name: user.name,
        radius: 22,
      ),
      title: user.name,
      subtitles: [
        if (user.isPlaceholder) _InvitedTag(isDark: isDark),
        ...lines,
      ],
      trailing: trailing,
      onTap: onTap,
      showDivider: showDivider,
      semanticsLabel: [
        user.name,
        if (user.isPlaceholder) AppStrings.invited,
        ...lines,
      ].join(', '),
    );
  }
}

class _InvitedTag extends StatelessWidget {
  const _InvitedTag({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        child: Text(
          AppStrings.invited,
          style: AppTextStyles.caption(
            isDark,
          ).copyWith(color: AppColors.textSecondary(isDark)),
        ),
      ),
    );
  }
}
