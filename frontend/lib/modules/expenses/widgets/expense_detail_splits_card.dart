import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../state/expense_detail_settle.dart';
import 'expense_detail_split_row.dart';

/// "Split among" card on the expense detail screen: one row per person,
/// a "Show working" toggle for percentage / shares splits, and per-row
/// Settle up / Remind actions.
class ExpenseDetailSplitsCard extends StatefulWidget {
  const ExpenseDetailSplitsCard({
    super.key,
    required this.splits,
    required this.currency,
    required this.isDark,
    required this.splitType,
    required this.totalAmount,
    this.currentUserId,
    this.memberById = const {},
    this.displayNames = const {},
    this.payerIds = const {},
    this.groupId,
    this.netByUserId = const {},
    this.pendingOutByUserId = const {},
    this.onSettle,
    this.onRemind,
  });

  final List<SplitModel> splits;
  final String currency;
  final bool isDark;
  final SplitType splitType;
  final String? currentUserId;
  final double totalAmount;

  /// Everyone who paid for the expense, and the group it belongs to.
  final Set<String> payerIds;
  final String? groupId;

  /// Net pairwise balance with each other person (>0 ⇒ I owe them, <0 ⇒ they
  /// owe me). The buttons are gated on this, so they vanish once settled.
  final Map<String, double> netByUserId;

  /// Amount I already have pending (unconfirmed) to each person — Settle Up
  /// only asks for the not-yet-in-flight remainder.
  final Map<String, double> pendingOutByUserId;

  /// Settle up with (payerId, amount). Only offered on my own row when one
  /// person paid; with several payers the Paid-by card offers it per payer.
  final void Function(String payerId, double amount)? onSettle;
  final void Function(String userId)? onRemind;

  /// userId → group member, used to backfill an avatar when a split row's own
  /// avatar is empty.
  final Map<String, UserModel> memberById;

  /// userId → resolved display name (real name → device contact → phone).
  final Map<String, String> displayNames;

  @override
  State<ExpenseDetailSplitsCard> createState() =>
      _ExpenseDetailSplitsCardState();
}

class _ExpenseDetailSplitsCardState extends State<ExpenseDetailSplitsCard> {
  bool _expanded = false;

  bool get _hasWorking =>
      widget.splitType == SplitType.percentage ||
      widget.splitType == SplitType.shares;

  /// The row's action chip, or null for no button.
  ({String label, IconData icon, Color color, VoidCallback onTap})? _action(
    SplitModel s,
  ) {
    final myId = widget.currentUserId;
    if (widget.groupId == null || myId == null) return null;
    if (widget.onRemind != null &&
        canRemindOnExpense(
          myId: myId,
          userId: s.userId,
          payerIds: widget.payerIds,
          netByUserId: widget.netByUserId,
        )) {
      // I paid AND this person still net-owes me → remind them.
      return (
        label: AppStrings.remind,
        icon: Icons.notifications_active_rounded,
        color: AppColors.brand,
        onTap: () => widget.onRemind!(s.userId),
      );
    }
    if (widget.payerIds.length == 1 &&
        !widget.payerIds.contains(myId) &&
        s.userId == myId &&
        widget.onSettle != null) {
      // Someone else paid and I still net-owe them (beyond what's already
      // pending) → settle the remaining amount.
      final payerId = widget.payerIds.first;
      final toSettle = remainingToSettle(
        userId: payerId,
        netByUserId: widget.netByUserId,
        pendingOutByUserId: widget.pendingOutByUserId,
      );
      if (toSettle > 0.01) {
        return (
          label: AppStrings.settleUp,
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.tealDark,
          onTap: () => widget.onSettle!(payerId, toSettle),
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final myId = widget.currentUserId;
    final totalShares = widget.splitType == SplitType.shares
        ? widget.splits.fold<double>(0, (s, e) => s + e.shares)
        : 0.0;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: AppColors.divider(isDark).withValues(alpha: 0.6),
    );

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < widget.splits.length; i++) ...[
            Builder(
              builder: (_) {
                final s = widget.splits[i];
                final action = _action(s);
                return ExpenseDetailSplitRow(
                  split: s,
                  currency: widget.currency,
                  isDark: isDark,
                  splitType: widget.splitType,
                  totalAmount: widget.totalAmount,
                  totalShares: totalShares,
                  showWorking: _expanded,
                  fallbackMember: widget.memberById[s.userId],
                  displayName: widget.displayNames[s.userId],
                  isSelf: myId != null && s.userId == myId,
                  actionLabel: action?.label,
                  actionIcon: action?.icon,
                  actionColor: action?.color,
                  onAction: action?.onTap,
                );
              },
            ),
            if (i < widget.splits.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: divider,
              ),
          ],
          if (_hasWorking) ...[
            divider,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textSecondary(isDark),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? 'Hide working' : 'Show working',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (!_hasWorking) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: card,
      ),
    );
  }
}
