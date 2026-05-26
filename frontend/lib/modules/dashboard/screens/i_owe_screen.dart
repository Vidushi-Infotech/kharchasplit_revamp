import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../state/balance_detail_provider.dart';
import '../widgets/balance_breakdown.dart';

/// Screen showing all groups where the user owes money.
class IOweScreen extends ConsumerWidget {
  const IOweScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(iOweGroupsProvider);
    final total = ref.watch(totalIOweProvider);
    return BalanceBreakdownView(
      overline: 'YOU OWE',
      total: total,
      amountSign: '-',
      subtitle: groups.isEmpty
          ? 'You have no pending dues'
          : 'Across ${groups.length} ${groups.length == 1 ? 'group' : 'groups'}',
      accent: AppColors.warning,
      groups: groups,
      emptyEmoji: '🥳',
      emptyTitle: 'No pending dues',
      emptyMessage: 'You don\'t owe anyone right now.',
    );
  }
}
