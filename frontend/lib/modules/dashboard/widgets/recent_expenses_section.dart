import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/models.dart';
import '../../auth/state/auth_provider.dart';

/// Compact, date-grouped list of recent expenses for the dashboard.
class RecentExpensesSection extends ConsumerWidget {
  const RecentExpensesSection({
    super.key,
    required this.expenses,
    required this.groups,
    this.onExpenseTap,
    this.onSeeAll,
    this.showHeader = true,
  });

  final List<ExpenseModel> expenses;
  final List<GroupModel> groups;
  final void Function(ExpenseModel expense)? onExpenseTap;
  final VoidCallback? onSeeAll;

  /// Whether to render the "Recent Expenses" header. Disabled when embedded in
  /// the "see all" sheet, which provides its own title (avoids a duplicate).
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(myIdProvider);
    final groupNames = {for (final g in groups) g.id: g.name};

    final grouped = <String, List<ExpenseModel>>{};
    for (final expense in expenses) {
      final header = DateFormatter.groupHeader(expense.date).toUpperCase();
      grouped.putIfAbsent(header, () => []).add(expense);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          _Header(isDark: isDark, onSeeAll: onSeeAll),
          const SizedBox(height: 12),
        ],
        if (expenses.isEmpty)
          _EmptyState(isDark: isDark)
        else
          ...grouped.entries.expand(
            (entry) => [
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                child: Text(
                  entry.key,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ),
              _ExpenseGroupCard(
                isDark: isDark,
                expenses: entry.value,
                currentUserId: currentUserId,
                groupNames: groupNames,
                onTap: onExpenseTap,
              ),
            ],
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark, this.onSeeAll});
  final bool isDark;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Recent Expenses',
            style: AppTextStyles.body1(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textSecondary(isDark),
          ),
        ],
      ],
    );

    if (onSeeAll == null) return title;

    return Semantics(
      button: true,
      label: 'Recent Expenses — see all',
      child: InkWell(
        onTap: onSeeAll,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: title,
        ),
      ),
    );
  }
}

class _ExpenseGroupCard extends StatelessWidget {
  const _ExpenseGroupCard({
    required this.isDark,
    required this.expenses,
    required this.currentUserId,
    required this.groupNames,
    this.onTap,
  });

  final bool isDark;
  final List<ExpenseModel> expenses;
  final String? currentUserId;
  final Map<String, String> groupNames;
  final void Function(ExpenseModel expense)? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < expenses.length; i++) ...[
            _ExpenseRow(
              expense: expenses[i],
              currentUserId: currentUserId,
              groupName: expenses[i].groupId == null
                  ? null
                  : groupNames[expenses[i].groupId],
              onTap: onTap == null ? null : () => onTap!(expenses[i]),
              isDark: isDark,
            ),
            if (i < expenses.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.currentUserId,
    required this.isDark,
    this.groupName,
    this.onTap,
  });

  final ExpenseModel expense;
  final String? currentUserId;
  final bool isDark;
  final String? groupName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final youPaid = currentUserId != null && expense.paidBy.id == currentUserId;
    final categoryColor = _parseHex(expense.category.colorHex);
    final isSettled = expense.isSettled;

    final (Color amountColor, String sign, String statusLabel) = isSettled
        ? (AppColors.textSecondary(isDark), '', 'Settled')
        : (
            youPaid ? AppColors.success : AppColors.warning,
            youPaid ? '+' : '-',
            youPaid ? 'you paid' : 'you owe',
          );

    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: expense.currency,
      decimalDigits: 0,
    ).format(expense.amount);

    final subtitle = [
      if (groupName != null && groupName!.isNotEmpty) groupName,
      statusLabel,
    ].whereType<String>().join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CategoryTile(icon: expense.category.icon, color: categoryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.title,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$sign$formatted',
                style: AppTextStyles.body1(isDark).copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              // Chevron affordance — signals the row opens the expense's group.
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary(isDark),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final padded = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.parse(padded, radix: 16));
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No expenses yet',
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Your recent activity will appear here',
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
