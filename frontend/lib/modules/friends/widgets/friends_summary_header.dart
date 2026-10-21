import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
import 'friend_balance_label.dart';

/// "Overall, you are owed ₹X" / "Overall, you owe ₹X" / "You are all
/// settled up", one line per currency, plus the hide-settled filter.
class FriendsSummaryHeader extends ConsumerWidget {
  const FriendsSummaryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totals = ref.watch(friendsTotalsProvider).value ?? const {};
    final hideSettled = ref.watch(hideSettledFriendsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: totals.isEmpty
                  ? [_line(AppStrings.youAreAllSettledUp, 0, isDark)]
                  : [
                      for (final e in totals.entries)
                        _line(
                          e.value > 0
                              ? AppStrings.overallYouAreOwed(
                                  formatFriendAmount(e.value, e.key))
                              : AppStrings.overallYouOwe(
                                  formatFriendAmount(e.value, e.key)),
                          e.value,
                          isDark,
                        ),
                    ],
            ),
          ),
          Semantics(
            toggled: hideSettled,
            label: AppStrings.hideSettledUpFriends,
            child: IconButton(
              tooltip: AppStrings.hideSettledUpFriends,
              isSelected: hideSettled,
              icon: const Icon(Icons.filter_list_rounded),
              selectedIcon: const Icon(Icons.filter_list_off_rounded),
              color: hideSettled
                  ? AppColors.brand
                  : AppColors.textSecondary(isDark),
              onPressed: () =>
                  ref.read(hideSettledFriendsProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String text, double net, bool isDark) {
    return Text(
      text,
      style: AppTextStyles.body1(isDark).copyWith(
        fontWeight: FontWeight.w600,
        color: net == 0
            ? AppColors.textSecondary(isDark)
            : friendBalanceColor(net, isDark),
      ),
    );
  }
}
