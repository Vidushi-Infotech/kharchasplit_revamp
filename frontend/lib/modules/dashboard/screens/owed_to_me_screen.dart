import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../state/balance_detail_provider.dart';
import '../widgets/balance_breakdown.dart';

/// Screen showing all groups where the user is owed money.
class OwedToMeScreen extends ConsumerWidget {
  const OwedToMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(owedToMeGroupsProvider);
    final total = ref.watch(totalOwedToMeProvider);
    return BalanceBreakdownView(
      overline: "YOU'RE OWED",
      total: total,
      amountSign: '+',
      subtitle: groups.isEmpty
          ? 'No outstanding amounts'
          : 'Across ${groups.length} ${groups.length == 1 ? 'group' : 'groups'}',
      accent: AppColors.success,
      groups: groups,
      // Show the pair-level "owed to me" total for THIS group, not the per-
      // group net. Otherwise a group where you net +566 but are actually
      // owed +2200 by one member would display ₹566 instead of ₹2200.
      amountExtractor: (g) => (g.youAreOwedInGroup as num).toDouble(),
      emptyEmoji: '🎉',
      emptyTitle: 'All settled up!',
      emptyMessage: 'No one owes you money right now.',
    );
  }
}
