import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/group_member_balances.dart';
import 'balance_member_row.dart';
import 'group_member_actions.dart';
import 'pending_incoming_settlements_section.dart';
import 'pending_outgoing_settlements_section.dart';
import 'simplified_balances_chip.dart';

/// Body of the Balances page: payments waiting on you (to confirm) or on
/// others, then one expandable row per member with their total balance in
/// the group. With "Simplify group debts" on, the rows use the simplified
/// transfers and a "Simplified" chip explains why.
///
/// One lazy ListView: index 0 is the pending sections + header, the rest
/// are member rows.
class GroupBalancesBody extends ConsumerWidget {
  const GroupBalancesBody({super.key, required this.detail});

  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupId = detail.group.id;
    final myId = ref.watch(myIdProvider);
    final balances =
        ref.watch(groupMemberBalancesProvider(groupId)) ?? const [];
    // What I've already got in pending (unconfirmed) payments to each
    // person — Settle up only asks for the not-yet-in-flight rest.
    final pendingOut = myId == null
        ? const <String, double>{}
        : computePendingOutgoing(myId: myId, settlements: detail.settlements);
    final allSettled = balances.every((b) => b.settled);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: balances.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PendingIncomingSettlementsSection(groupId: groupId),
              PendingOutgoingSettlementsSection(groupId: groupId),
              _Header(
                isDark: isDark,
                simplified: detail.group.simplifyDebts,
                allSettled: allSettled,
              ),
            ],
          );
        }
        final balance = balances[index - 1];
        return BalanceMemberRow(
          key: ValueKey(balance.member.id),
          balance: balance,
          myId: myId,
          currency: detail.group.currency,
          pendingOut: pendingOut,
          onRemind: (debtor) =>
              sendGroupReminder(groupId, context, ref, debtor),
          onSettle: (creditor, amount) => context.push(
            '/settle/${creditor.id}?groupId=$groupId'
            '&amount=${amount.toStringAsFixed(2)}',
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isDark,
    required this.simplified,
    required this.allSettled,
  });

  final bool isDark;
  final bool simplified;
  final bool allSettled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                header: true,
                child: Text(
                  AppStrings.balances,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Shown whenever the group is simplified, even with the
              // simplifyDebts flag off — the numbers are simplified.
              if (simplified) ...[
                const SizedBox(width: 8),
                const SimplifiedBalancesChip(),
              ],
            ],
          ),
          if (allSettled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppStrings.allSettledUp,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
