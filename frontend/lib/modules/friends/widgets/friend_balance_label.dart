import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/friends_provider.dart';

/// Money colour for a signed balance: green = owed to you, red = you owe,
/// gray = settled.
Color friendBalanceColor(double net, bool isDark) {
  if (net > 0.005) return AppColors.success;
  if (net < -0.005) return AppColors.errorText(isDark);
  return AppColors.textSecondary(isDark);
}

/// Formats an amount (absolute value) in an ISO currency.
String formatFriendAmount(double amount, String currency) =>
    CurrencyFormatter.format(amount.abs(), currency: currency);

/// "In Goa trip ₹500 · Flat ₹200 · +1 more" — only when the friend has
/// balances in more than one group; `null` otherwise.
String? friendGroupsSubtitle(FriendBalance f) {
  if (f.groups.length < 2) return null;
  final shown = f.groups
      .take(2)
      .map((g) => '${g.groupName} ${formatFriendAmount(g.net, g.currency)}')
      .join(' · ');
  final more = f.groups.length - 2;
  return 'In $shown${more > 0 ? ' · +$more more' : ''}';
}

/// Right-aligned "owes you ₹X" / "you owe ₹X" / "settled up" for a friend
/// row. Mixed currencies get one line per currency — never converted.
class FriendBalanceLabel extends StatelessWidget {
  const FriendBalanceLabel({super.key, required this.friend});

  final FriendBalance friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final byCurrency = friend.netByCurrency;

    if (byCurrency.isEmpty) {
      return Text(
        AppStrings.settledUpLower,
        style: AppTextStyles.caption(isDark)
            .copyWith(color: friendBalanceColor(0, isDark)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in byCurrency.entries) ...[
          Text(
            entry.value > 0 ? AppStrings.owesYou : AppStrings.youOweLower,
            style: AppTextStyles.caption(isDark)
                .copyWith(color: friendBalanceColor(entry.value, isDark)),
          ),
          Text(
            formatFriendAmount(entry.value, entry.key),
            style: AppTextStyles.body1(isDark).copyWith(
              color: friendBalanceColor(entry.value, isDark),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
