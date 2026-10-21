import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
import 'friend_balance_label.dart';

/// Per-group breakdown as a sliver: "In Goa trip: Asha owes you ₹500" /
/// "In Flat: you owe ₹200" / "Non-group expenses: you owe ₹100". Tapping a
/// row opens the group (the hidden non-group one too).
class FriendGroupBalancesSliver extends StatelessWidget {
  const FriendGroupBalancesSliver({super.key, required this.friend});

  final FriendBalance friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = friend.groups;
    if (groups.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList.builder(
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              AppStrings.balances,
              style: AppTextStyles.headline3(isDark).copyWith(fontSize: 18),
            ),
          );
        }
        final g = groups[index - 1];
        final amount = formatFriendAmount(g.net, g.currency);
        final String text;
        if (g.isDirect) {
          text = g.net > 0
              ? AppStrings.nonGroupNameOwesYou(friend.user.name, amount)
              : AppStrings.nonGroupYouOwe(amount);
        } else {
          text = g.net > 0
              ? AppStrings.inGroupNameOwesYou(
                  g.groupName, friend.user.name, amount)
              : AppStrings.inGroupYouOwe(g.groupName, amount);
        }
        return Semantics(
          button: true,
          label: '$text. Open group',
          child: ListTile(
            leading: Icon(
              g.isDirect ? Icons.person_outline_rounded : Icons.group_outlined,
              color: AppColors.textSecondary(isDark),
            ),
            title: Text(
              text,
              style: AppTextStyles.body2(isDark).copyWith(
                color: friendBalanceColor(g.net, isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/home/groups/${g.groupId}'),
          ),
        );
      },
    );
  }
}
