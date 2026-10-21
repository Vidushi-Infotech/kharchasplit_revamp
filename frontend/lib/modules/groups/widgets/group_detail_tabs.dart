import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_balance_helpers.dart';
import '../state/group_detail_provider.dart';
import 'group_tab_button.dart';

Widget buildGroupTabs(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupTab tab,
  WidgetRef ref,
) {
  // Watch the provider exactly once and reuse the AsyncValue, avoiding
  // a second listener subscription per build (and a redundant rebuild).
  final detailAsync = ref.watch(groupDetailProvider(groupId));
  final detail = detailAsync.value;
  final myId = ref.watch(myIdProvider);

  // The Balances badge previously showed member count, which read as
  // "2 outstanding balances" on a brand-new group with zero expenses.
  // Show the count of *active pairwise debts* (`|net| > 0.01`) instead —
  // matches what the Balances tab actually renders.
  int? balancesCount;
  if (detail != null && myId != null) {
    final pair = groupVisibleDebts(myId: myId, detail: detail);
    balancesCount = pair.values.where((v) => v.abs() > 0.01).length;
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          GroupTabButton(
            label: 'Expenses',
            icon: Icons.receipt_long_rounded,
            count: detail?.expenses.length,
            selected: tab == GroupTab.expenses,
            isDark: isDark,
            onTap: () {
              if (tab != GroupTab.expenses) {
                HapticService.instance.selection();
                ref.read(groupTabProvider.notifier).state = GroupTab.expenses;
              }
            },
          ),
          const SizedBox(width: 6),
          GroupTabButton(
            label: 'Balances',
            icon: Icons.balance_rounded,
            count: balancesCount,
            selected: tab == GroupTab.balances,
            isDark: isDark,
            onTap: () {
              if (tab != GroupTab.balances) {
                HapticService.instance.selection();
                ref.read(groupTabProvider.notifier).state = GroupTab.balances;
              }
            },
          ),
          const SizedBox(width: 6),
          GroupTabButton(
            label: 'Activity',
            icon: Icons.history_rounded,
            count: detail == null
                ? null
                : detail.expenses.length + detail.settlements.length,
            selected: tab == GroupTab.activity,
            isDark: isDark,
            onTap: () {
              if (tab != GroupTab.activity) {
                HapticService.instance.selection();
                ref.read(groupTabProvider.notifier).state = GroupTab.activity;
              }
            },
          ),
          const SizedBox(width: 6),
          GroupTabButton(
            label: AppStrings.totalsTab,
            icon: Icons.pie_chart_outline_rounded,
            selected: tab == GroupTab.totals,
            isDark: isDark,
            onTap: () {
              if (tab != GroupTab.totals) {
                HapticService.instance.selection();
                ref.read(groupTabProvider.notifier).state = GroupTab.totals;
              }
            },
          ),
        ],
      ),
    ),
  );
}
