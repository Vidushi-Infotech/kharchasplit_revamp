import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../components/web/hoverable.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
import 'friend_balance_label.dart';

/// One row of the Friends list: avatar, name (+ "Invited" tag for
/// placeholder users), per-group subtitle, and the balance on the right.
class FriendListTile extends StatelessWidget {
  const FriendListTile({
    super.key,
    required this.friend,
    required this.onTap,
    this.hoverable = false,
  });

  final FriendBalance friend;
  final VoidCallback onTap;

  /// Web tiers: wrap in [Hoverable] for cursor, hover lift and focus ring.
  final bool hoverable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = friend.user;
    final subtitle = friendGroupsSubtitle(friend);

    final tile = Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: AvatarWidget(
          imageUrl: user.avatarUrl,
          name: user.name,
          radius: 22,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body1(isDark)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (user.isPlaceholder) ...[
              const SizedBox(width: 8),
              _InvitedTag(isDark: isDark),
            ],
          ],
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(isDark),
              ),
        trailing: FriendBalanceLabel(friend: friend),
        // On web the tap is handled by the hover wrapper.
        onTap: hoverable ? null : onTap,
      ),
    );

    if (!hoverable) return tile;
    return Hoverable(
      borderRadius: 12,
      semanticLabel: 'Open ${user.name}',
      onTap: onTap,
      child: tile,
    );
  }
}

class _InvitedTag extends StatelessWidget {
  const _InvitedTag({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Text(
        AppStrings.invited,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
        ),
      ),
    );
  }
}
