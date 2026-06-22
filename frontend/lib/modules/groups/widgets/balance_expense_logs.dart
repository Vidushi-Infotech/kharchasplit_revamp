import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/models.dart';

/// One owe/owed line, derived from a SINGLE split of a SINGLE expense.
class SplitLogEntry {
  const SplitLogEntry({
    required this.personId,
    required this.personName,
    required this.personAvatar,
    required this.theyOweMe,
    required this.amount,
    required this.expense,
  });

  /// userId of the other party (the debtor if [theyOweMe], else the payer).
  final String personId;

  /// The other party in this line (the debtor if [theyOweMe], else the payer).
  final String personName;
  final String? personAvatar;

  /// true  → [personName] owes the current user [amount] for this expense
  /// false → the current user owes [personName] [amount] for this expense
  final bool theyOweMe;
  final double amount;
  final ExpenseModel expense;
}

/// Builds the per-SPLIT log entries (one row per person per expense — never
/// rolled up). Newest expense first; split rows within an expense keep order.
/// Only includes splits that involve the current user (I paid → others owe me;
/// someone else paid → I owe them).
List<SplitLogEntry> buildSplitLogEntries({
  required List<ExpenseModel> expenses,
  required String? currentUserId,
  Map<String, UserModel> memberById = const {},
}) {
  final myId = currentUserId;
  if (myId == null) return const [];

  String nameFor(String userId, String fallback) {
    final m = memberById[userId];
    final n = (m?.name ?? '').trim();
    if (n.isNotEmpty) return n;
    final fb = fallback.trim();
    return fb.isNotEmpty ? fb : 'Member';
  }

  final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
  final out = <SplitLogEntry>[];
  for (final e in sorted) {
    if (e.paidBy.id == myId) {
      for (final s in e.splits) {
        if (s.userId == myId) continue;
        if (s.owedShare <= 0.01) continue;
        out.add(
          SplitLogEntry(
            personId: s.userId,
            personName: nameFor(s.userId, s.userName),
            personAvatar: memberById[s.userId]?.avatarUrl ?? s.userAvatarUrl,
            theyOweMe: true,
            amount: s.owedShare,
            expense: e,
          ),
        );
      }
    } else {
      final mine = e.splits.firstWhereOrNull((s) => s.userId == myId);
      if (mine != null && mine.owedShare > 0.01) {
        out.add(
          SplitLogEntry(
            personId: e.paidBy.id,
            personName: nameFor(e.paidBy.id, e.paidBy.name),
            personAvatar:
                memberById[e.paidBy.id]?.avatarUrl ?? e.paidBy.avatarUrl,
            theyOweMe: false,
            amount: mine.owedShare,
            expense: e,
          ),
        );
      }
    }
  }
  return out;
}

/// A single owe/owed log row for one split of one expense.
class SplitLogRow extends StatelessWidget {
  const SplitLogRow({
    super.key,
    required this.entry,
    required this.onTap,
    this.onSettle,
    this.onRemind,
  });

  final SplitLogEntry entry;
  final VoidCallback onTap;

  /// "Settle Up" — shown when you owe this person ([entry.theyOweMe] false).
  final VoidCallback? onSettle;

  /// "Remind" — shown when this person owes you ([entry.theyOweMe] true).
  final VoidCallback? onRemind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = entry.theyOweMe ? AppColors.success : AppColors.warning;
    final showRemind = entry.theyOweMe && onRemind != null;
    final showSettle = !entry.theyOweMe && onSettle != null;
    final firstName = entry.personName.trim().split(' ').first;
    final relation = entry.theyOweMe
        ? '$firstName owes you'
        : 'You owe $firstName';
    final dateStr = DateFormat('d MMM').format(entry.expense.date);
    final subtitle = '${entry.expense.title} · $dateStr';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Row(
            children: [
              AvatarWidget(
                name: entry.personName,
                imageUrl: entry.personAvatar,
                radius: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      relation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      CurrencyFormatter.format(entry.amount),
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (showSettle) ...[
                    const SizedBox(height: 6),
                    _LogAction(
                      label: 'Settle Up',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.tealDark,
                      onTap: onSettle!,
                    ),
                  ] else if (showRemind) ...[
                    const SizedBox(height: 6),
                    _LogAction(
                      label: 'Remind',
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.brand,
                      onTap: onRemind!,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact Settle Up / Remind chip used on a log row.
class _LogAction extends StatelessWidget {
  const _LogAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
