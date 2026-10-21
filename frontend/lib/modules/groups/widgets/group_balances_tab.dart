import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/user_model.dart';
import '../state/group_balance_helpers.dart';
import '../state/group_detail_provider.dart';
import 'balance_expense_logs.dart';
import 'balance_summary_cards.dart';
import 'group_member_actions.dart';
import 'pending_incoming_settlements_section.dart';
import 'pending_outgoing_settlements_section.dart';
import 'received_settlements_section.dart';
import 'simplified_balances_chip.dart';

Widget buildGroupBalancesTab(
  String groupId,
  BuildContext context,
  WidgetRef ref,
  bool isDark,
  GroupDetail detail,
  String? myId,
) {
  final isCompact = MediaQuery.sizeOf(context).width < 600;
  final pad = isCompact ? 16.0 : 24.0;

  // What I've already got in pending (unconfirmed) settlements to each
  // person — so Settle Up only asks for the not-yet-in-flight remainder.
  final pendingOut = myId == null
      ? const <String, double>{}
      : computePendingOutgoing(myId: myId, settlements: detail.settlements);

  final cards = myId == null
      ? const <BalanceCardData>[]
      : buildBalanceCardData(
          myId: myId,
          detail: detail,
          pendingOut: pendingOut,
        );

  // Net pairwise balance with each person — used to gate the Settle Up /
  // Remind buttons on the log rows. pair[id] > 0 ⇒ I owe them; < 0 ⇒ they
  // owe me; ~0 ⇒ settled (so no button — this is what "disables Settle Up
  // once everything's settled" rather than reacting to a single expense).
  final pair = myId == null
      ? const <String, double>{}
      : groupVisibleDebts(myId: myId, detail: detail);

  // Per-split log entries, computed once and rendered lazily below.
  final logEntries = buildSplitLogEntries(
    expenses: detail.expenses,
    currentUserId: myId,
    memberById: {for (final m in detail.members) m.id: m},
  );

  // CustomScrollView so the (potentially long) per-split log builds lazily
  // via a SliverList.builder instead of all at once.
  // A single ListView.builder — the same reliable NestedScrollView body the
  // Expenses tab uses. Index 0 is the settlements + balance cards + the
  // "Expense log" header; indices 1.. are the lazily-built per-split log
  // rows. (A CustomScrollView here failed to scroll / show the log in
  // release builds.)
  return ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.only(bottom: 12),
    itemCount: logEntries.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PendingIncomingSettlementsSection(groupId: groupId),
            PendingOutgoingSettlementsSection(groupId: groupId),
            if (cards.isEmpty)
              _buildAllSettledCard(isDark, pad)
            else ...[
              _buildSectionHeader(
                'Balances',
                isDark: isDark,
                padding: pad,
                // Shown whenever the group is simplified, even with the
                // simplifyDebts flag off — the numbers are simplified.
                trailing: detail.group.simplifyDebts
                    ? const SimplifiedBalancesChip()
                    : null,
              ),
              const SizedBox(height: 8),
              BalanceSummaryCards(
                entries: cards,
                horizontalPadding: pad,
                onTap: (entry) {
                  // No drill-in for your own card or a settled member.
                  if (entry.isMe || entry.settled) return;
                  context.push(
                    '/home/groups/$groupId/settlements-with/${entry.member.id}',
                  );
                },
                onSettle: (entry) => context.push(
                  '/settle/${entry.member.id}?groupId=$groupId'
                  '&amount=${entry.settleAmount.toStringAsFixed(2)}',
                ),
                onRemind: (entry) =>
                    sendGroupReminder(groupId, context, ref, entry.member),
              ),
            ],
            if (myId != null)
              ReceivedSettlementsSection(
                groupId: groupId,
                myId: myId,
                settlements: detail.settlements,
                padding: pad,
              ),
            if (logEntries.isNotEmpty) ...[
              const SizedBox(height: 22),
              _buildSectionHeader('Expense log', isDark: isDark, padding: pad),
              const SizedBox(height: 8),
            ],
          ],
        );
      }

      final entry = logEntries[index - 1];
      // Gate the action by the NET balance with this person, not the single
      // expense's share. Once the net is settled, neither button shows.
      final net = pair[entry.personId] ?? 0;
      final iOweNet = net > 0.01; // I still owe them overall
      final theyOweMeNet = net < -0.01; // they still owe me overall
      // Guard the clamp: clamp(0, negative) throws when net <= 0.
      final pendOut = pendingOut[entry.personId] ?? 0;
      final toSettle = net > 0 ? (net - pendOut).clamp(0, net).toDouble() : 0.0;
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
        child: SplitLogRow(
          entry: entry,
          onTap: () => context.push('/expense/${entry.expense.id}'),
          onRemind: (entry.theyOweMe && theyOweMeNet)
              ? () => sendGroupReminder(
                  groupId,
                  context,
                  ref,
                  detail.members.firstWhere(
                    (m) => m.id == entry.personId,
                    orElse: () => UserModel(
                      id: entry.personId,
                      name: entry.personName,
                      email: '',
                      phone: '',
                      createdAt: DateTime.now(),
                    ),
                  ),
                )
              : null,
          onSettle: (!entry.theyOweMe && iOweNet && toSettle > 0.01)
              ? () => context.push(
                  '/settle/${entry.personId}?groupId=$groupId'
                  '&amount=${toSettle.toStringAsFixed(2)}',
                )
              : null,
        ),
      );
    },
  );
}

Widget _buildAllSettledCard(bool isDark, double padding) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 1),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            'All settled up',
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'No one owes anyone in this group.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSectionHeader(
  String label, {
  required bool isDark,
  required double padding,
  Widget? trailing,
}) {
  final text = Text(
    label.toUpperCase(),
    style: AppTextStyles.caption(isDark).copyWith(
      color: AppColors.textSecondary(isDark),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),
  );
  return Padding(
    padding: EdgeInsets.fromLTRB(padding, 4, padding, 8),
    child: trailing == null
        ? text
        : Row(children: [text, const SizedBox(width: 8), trailing]),
  );
}
