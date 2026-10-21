import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
import 'friend_balance_label.dart';

/// Avatar, name and the overall balance with this friend ("Asha owes you
/// ₹500" / "You owe Asha ₹200" / "You are all settled up with Asha"), one
/// line per currency.
class FriendDetailHeader extends StatelessWidget {
  const FriendDetailHeader({super.key, required this.friend});

  final FriendBalance friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = friend.user;
    final byCurrency = friend.netByCurrency;
    final subtitle = user.email.isNotEmpty ? user.email : user.phone;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(bottom: BorderSide(color: AppColors.divider(isDark))),
      ),
      child: Column(
        children: [
          AvatarWidget(imageUrl: user.avatarUrl, name: user.name, radius: 40),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: AppTextStyles.headline3(isDark),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.caption(isDark)),
          ],
          if (user.isPlaceholder) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.invited,
              style: AppTextStyles.caption(isDark)
                  .copyWith(color: AppColors.textSecondary(isDark)),
            ),
          ],
          const SizedBox(height: 16),
          if (byCurrency.isEmpty)
            _BalanceLine(
              text: AppStrings.settledUpWith(user.name),
              net: 0,
              isDark: isDark,
            )
          else
            for (final e in byCurrency.entries)
              _BalanceLine(
                text: e.value > 0
                    ? AppStrings.nameOwesYou(
                        user.name, formatFriendAmount(e.value, e.key))
                    : AppStrings.youOweName(
                        user.name, formatFriendAmount(e.value, e.key)),
                net: e.value,
                isDark: isDark,
              ),
        ],
      ),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({
    required this.text,
    required this.net,
    required this.isDark,
  });

  final String text;
  final double net;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.body1(isDark).copyWith(
          fontWeight: FontWeight.w700,
          color: friendBalanceColor(net, isDark),
        ),
      ),
    );
  }
}
