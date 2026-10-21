import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/contacts/contact_name_resolver.dart';
import '../../../models/models.dart';
import '../state/expense_detail_settle.dart';

/// "Paid by" card on the expense detail screen. One payer → a single row
/// ("paid the full amount"); several → "Asha paid ₹600 · Ravi paid ₹400"
/// and a row per payer, each with Settle up when I still owe that person.
class ExpenseDetailPaidBy extends StatelessWidget {
  const ExpenseDetailPaidBy({
    super.key,
    required this.expense,
    required this.isDark,
    required this.myId,
    required this.memberById,
    required this.contactNameByPhone,
    this.netByUserId = const {},
    this.pendingOutByUserId = const {},
    this.onSettle,
  });

  final ExpenseModel expense;
  final bool isDark;
  final String? myId;
  final Map<String, UserModel> memberById;
  final Map<String, String> contactNameByPhone;
  final Map<String, double> netByUserId;
  final Map<String, double> pendingOutByUserId;
  final void Function(String payerId, double amount)? onSettle;

  String _money(double v) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: expense.currency,
        decimalDigits: 0,
      ).format(v);

  /// The per-group endpoint sends a flat name with no avatar: resolve the
  /// name (real → contact → phone) and avatar from the group member.
  String _name(String userId, String backendName) => resolveDisplayName(
        backendName: backendName,
        phone: memberById[userId]?.phone ?? '',
        contactNameByPhone: contactNameByPhone,
        placeholder: 'Unknown',
      );

  @override
  Widget build(BuildContext context) {
    if (!expense.hasMultiplePayers) {
      final own = expense.paidBy.avatarUrl;
      return _PayerRow(
        name: _name(expense.paidBy.id, expense.paidBy.name),
        imageUrl: (own != null && own.isNotEmpty)
            ? own
            : memberById[expense.paidBy.id]?.avatarUrl,
        subtitle: 'paid the full amount',
        amount: '+${_money(expense.amount)}',
        isDark: isDark,
        isSelf: myId != null && expense.paidBy.id == myId,
      );
    }

    final payers = [...expense.payers]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final summary = payers
        .map((p) => AppStrings.namePaidAmount(
              p.userId == myId ? 'You' : _name(p.userId, p.name),
              _money(p.amount),
            ))
        .join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              summary,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final p in payers) _rowFor(p),
        ],
      ),
    );
  }

  Widget _rowFor(ExpensePayer p) {
    final isSelf = myId != null && p.userId == myId;
    final toSettle = (isSelf || myId == null || expense.groupId == null)
        ? 0.0
        : remainingToSettle(
            userId: p.userId,
            netByUserId: netByUserId,
            pendingOutByUserId: pendingOutByUserId,
          );
    return _PayerRow(
      name: _name(p.userId, p.name),
      imageUrl: memberById[p.userId]?.avatarUrl,
      subtitle: 'paid ${_money(p.amount)} of ${_money(expense.amount)}',
      amount: '+${_money(p.amount)}',
      isDark: isDark,
      isSelf: isSelf,
      framed: false,
      onSettle: onSettle != null && toSettle > 0.01
          ? () => onSettle!(p.userId, toSettle)
          : null,
    );
  }
}

class _PayerRow extends StatelessWidget {
  const _PayerRow({
    required this.name,
    required this.imageUrl,
    required this.subtitle,
    required this.amount,
    required this.isDark,
    this.isSelf = false,
    this.framed = true,
    this.onSettle,
  });

  final String name;
  final String? imageUrl;
  final String subtitle;
  final String amount;
  final bool isDark;

  /// The signed-in user; " (Me)" is appended so they spot their own row.
  final bool isSelf;

  /// Draws its own card (single payer) or sits inside the multi-payer card.
  final bool framed;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AvatarWidget(name: name, imageUrl: imageUrl, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSelf ? '$name (Me)' : name,
                  style: AppTextStyles.body1(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: AppTextStyles.body1(isDark).copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              if (onSettle != null) ...[
                const SizedBox(height: 6),
                Semantics(
                  button: true,
                  label: '${AppStrings.settleUp} with $name',
                  child: Material(
                    color: AppColors.tealDark.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onSettle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          AppStrings.settleUp,
                          style: TextStyle(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (!framed) return row;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: row,
    );
  }
}
