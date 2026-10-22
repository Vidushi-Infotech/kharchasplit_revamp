import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friend_detail_view.dart';
import '../state/friends_provider.dart';
import 'friend_group_balances.dart';

/// Under the banner: the friend's name, their email / phone (or
/// "Invited"), the overall balance in its tone color — one line per
/// currency, never converted — and the gray per-group lines.
class FriendDetailHeader extends StatelessWidget {
  const FriendDetailHeader({
    super.key,
    required this.friend,
    this.horizontalPadding = 16,
  });

  final FriendBalance friend;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final user = friend.user;
    final contact = user.isPlaceholder
        ? AppStrings.invited
        : user.email.isNotEmpty
            ? user.email
            : user.phone;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary(isDark),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              friendDisplayName(user.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (contact.isNotEmpty)
            Text(
              contact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: secondary,
            ),
          const SizedBox(height: 6),
          for (final line in friendOverallLines(friend))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line.text,
                style: textTheme.titleMedium?.copyWith(
                  color: line.tone.color(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          FriendGroupBalanceLines(friend: friend),
        ],
      ),
    );
  }
}
