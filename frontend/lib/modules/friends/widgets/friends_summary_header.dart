import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friends_provider.dart';
import 'friend_balance_label.dart';

/// "Overall, you are owed ₹X" / "Overall, you owe ₹X" / "You are all
/// settled up" with the hide-settled filter on the right, then a hairline.
/// Mixed currencies are never converted, so they get one line each.
class FriendsSummaryHeader extends ConsumerWidget {
  const FriendsSummaryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totals = ref.watch(friendsTotalsProvider).value ?? const {};
    const filter = _HideSettledButton();

    final Widget summary;
    if (totals.length <= 1) {
      final e = totals.entries.firstOrNull;
      summary = OverallBalanceHeader(
        net: e?.value ?? 0,
        currency: e?.key ?? 'INR',
        trailing: filter,
      );
    } else {
      summary = Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in totals.entries)
                    Text(
                      e.value > 0
                          ? AppStrings.overallYouAreOwed(
                              formatFriendAmount(e.value, e.key),
                            )
                          : AppStrings.overallYouOwe(
                              formatFriendAmount(e.value, e.key),
                            ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BalanceTone.fromAmount(e.value).color(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            filter,
          ],
        ),
      );
    }

    return Column(
      children: [
        summary,
        Divider(height: 1, color: AppColors.divider(isDark)),
      ],
    );
  }
}

class _HideSettledButton extends ConsumerWidget {
  const _HideSettledButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideSettled = ref.watch(hideSettledFriendsProvider);
    return Semantics(
      toggled: hideSettled,
      label: AppStrings.hideSettledUpFriends,
      child: IconButton(
        tooltip: AppStrings.hideSettledUpFriends,
        isSelected: hideSettled,
        icon: const Icon(Icons.tune_rounded),
        selectedIcon: const Icon(Icons.filter_alt_rounded),
        color: hideSettled ? AppColors.brand : AppColors.textSecondary(isDark),
        onPressed: () => ref.read(hideSettledFriendsProvider.notifier).toggle(),
      ),
    );
  }
}
