import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/name_format.dart';
import '../../../data/contacts/contact_name_resolver.dart';
import '../../../models/models.dart';
import '../state/expense_detail_lines.dart';
import '../state/expense_detail_settle.dart';

/// Who paid and who owes, one flat line per person ("Asha K. paid ₹600.00
/// and owes ₹400.00", "You owe ₹200.00"), with Settle up / Remind where
/// the OUTSTANDING net with that person allows it, the split method note
/// and — for percentage / shares — a "Show working" toggle.
class ExpenseDetailPeople extends StatefulWidget {
  const ExpenseDetailPeople({
    super.key,
    required this.expense,
    required this.isDark,
    required this.myId,
    required this.memberById,
    required this.contactNameByPhone,
    this.netByUserId = const {},
    this.pendingOutByUserId = const {},
    this.onSettle,
    this.onRemind,
  });

  final ExpenseModel expense;
  final bool isDark;
  final String? myId;

  /// userId → group member: names / avatars for rows the server sent blank.
  final Map<String, UserModel> memberById;
  final Map<String, String> contactNameByPhone;

  /// Net pairwise balance with each person (> 0 ⇒ I owe them, < 0 ⇒ they
  /// owe me) and what I already have pending to them.
  final Map<String, double> netByUserId;
  final Map<String, double> pendingOutByUserId;
  final void Function(String payerId, double amount)? onSettle;
  final void Function(String userId)? onRemind;

  @override
  State<ExpenseDetailPeople> createState() => _ExpenseDetailPeopleState();
}

class _ExpenseDetailPeopleState extends State<ExpenseDetailPeople> {
  bool _showWorking = false;

  ExpenseModel get _e => widget.expense;

  /// Settle up / Remind for [p]'s row, or null. Same rules as before the
  /// redesign: Remind when I paid and they still net-owe me; Settle up on
  /// my own row when one other person paid, or on each other payer's row
  /// when several paid.
  ({String label, VoidCallback onTap})? _action(ExpensePersonShare p) {
    final myId = widget.myId;
    if (_e.groupId == null || myId == null) return null;
    final payerIds = {for (final x in expensePayersOf(_e)) x.userId};
    if (widget.onRemind != null &&
        canRemindOnExpense(
          myId: myId,
          userId: p.userId,
          payerIds: payerIds,
          netByUserId: widget.netByUserId,
        )) {
      return (
        label: AppStrings.remind,
        onTap: () => widget.onRemind!(p.userId),
      );
    }
    if (widget.onSettle == null) return null;
    String? settleWith;
    if (payerIds.length == 1 &&
        !payerIds.contains(myId) &&
        p.userId == myId &&
        p.split != null) {
      settleWith = payerIds.first;
    } else if (payerIds.length > 1 &&
        p.userId != myId &&
        payerIds.contains(p.userId)) {
      settleWith = p.userId;
    }
    if (settleWith == null) return null;
    final toSettle = remainingToSettle(
      userId: settleWith,
      netByUserId: widget.netByUserId,
      pendingOutByUserId: widget.pendingOutByUserId,
    );
    if (toSettle <= 0.01) return null;
    final target = settleWith;
    return (
      label: AppStrings.settleUp,
      onTap: () => widget.onSettle!(target, toSettle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final people = expensePeopleShares(_e);
    final hasWorking =
        _e.splitType == SplitType.percentage ||
        _e.splitType == SplitType.shares;
    final totalShares = _e.splitType == SplitType.shares
        ? _e.splits.fold<double>(0, (t, s) => t + s.shares)
        : 0.0;
    final secondary = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One row per person on the expense — a handful, so no builder.
        for (final p in people) _row(p, totalShares),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${expenseSplitMethodLabel(_e)} · '
                  '${AppStrings.peopleCount(_e.splits.length)}',
                  style: secondary,
                ),
              ),
              if (hasWorking)
                TextButton(
                  onPressed: () => setState(() => _showWorking = !_showWorking),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.tealDark,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    _showWorking
                        ? AppStrings.hideWorking
                        : AppStrings.showWorking,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(ExpensePersonShare p, double totalShares) {
    final isDark = widget.isDark;
    final member = widget.memberById[p.userId];
    // Blank / phone-only names → device contact → phone (as before).
    final name = resolveDisplayName(
      backendName: p.name.trim().isNotEmpty ? p.name : (member?.name ?? ''),
      phone: member?.phone ?? '',
      contactNameByPhone: widget.contactNameByPhone,
      placeholder: 'Unknown',
    );
    final isYou = widget.myId != null && p.userId == widget.myId;
    final own = p.split?.userAvatarUrl;
    final avatar = (own != null && own.isNotEmpty) ? own : member?.avatarUrl;
    final working = _showWorking && p.split != null
        ? expenseWorkingLine(
            split: p.split!,
            splitType: _e.splitType,
            totalAmount: _e.amount,
            totalShares: totalShares,
            currency: _e.currency,
          )
        : null;
    final action = _action(p);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AvatarWidget(name: name, imageUrl: avatar, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expensePersonLine(
                    name: NameFormat.short(name),
                    isYou: isYou,
                    paid: p.paid,
                    owes: p.owes,
                    currency: _e.currency,
                  ),
                  style: AppTextStyles.body1(isDark).copyWith(fontSize: 15),
                ),
                if (working != null)
                  Text(
                    working,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: '${action.label}, $name',
              excludeSemantics: true,
              child: OutlinedButton(
                onPressed: action.onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tealDark,
                  side: BorderSide(
                    color: AppColors.tealDark.withValues(alpha: 0.5),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(action.label),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
