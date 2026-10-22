import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friend_detail_view.dart';
import '../state/friends_provider.dart';

/// Gray per-group lines under the overall balance: "In Goa trip, Test F.
/// owes you ₹200.00" / "In non-group expenses, you owe Test F. ₹50.00".
/// Every group with an open balance is listed (the server sends only those)
/// and each line opens its group — the hidden non-group one too.
class FriendGroupBalanceLines extends StatelessWidget {
  const FriendGroupBalanceLines({super.key, required this.friend});

  final FriendBalance friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary(isDark),
          height: 1.35,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in friend.groups)
          Semantics(
            button: true,
            label: '${friendGroupLine(g, friend.user.name)}. '
                '${AppStrings.friendOpenGroup}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/home/groups/${g.groupId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(friendGroupLine(g, friend.user.name), style: style),
              ),
            ),
          ),
      ],
    );
  }
}
