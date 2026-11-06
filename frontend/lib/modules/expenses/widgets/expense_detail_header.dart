import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../data/expenses/expense_extras_repository.dart';
import '../../../models/models.dart';
import '../state/expense_detail_lines.dart';
import '../state/expense_history_provider.dart';
import 'expense_original_amount_line.dart';

/// Top of the expense detail screen, flat (Splitwise style): a big
/// category tile next to the description, the amount, the date (and
/// "Added on …" when that was another day), "Updated by … on …" once
/// edited, and the pending-sync badge.
class ExpenseDetailHeader extends ConsumerWidget {
  const ExpenseDetailHeader({
    super.key,
    required this.expense,
    required this.isDark,
    required this.myId,
  });

  final ExpenseModel expense;
  final bool isDark;
  final String? myId;

  static final _date = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark), fontSize: 13);
    // Only fetch the edit history when there's an edit to name (and the
    // expense exists on the server).
    final ExpenseRevision? lastEdit =
        expenseWasEdited(expense) && !expense.isPendingSync
        ? ref
              .watch(expenseHistoryProvider(expense.id))
              .value
              ?.revisions
              .firstOrNull
        : null;
    final editor = lastEdit == null
        ? null
        : (lastEdit.editorId != null && lastEdit.editorId == myId)
        ? AppStrings.youLower
        : NameFormat.short(lastEdit.editorName ?? 'Former member');

    final spentOn = _date.format(expense.date.toLocal());
    final addedOn = _date.format(expense.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryTile.forCategory(expense.category, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.format(
                    expense.amount,
                    currency: expense.currency,
                  ),
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                // Entered in another currency: what was paid, and the rate.
                ExpenseOriginalAmountLine(expense: expense),
                const SizedBox(height: 4),
                Text(
                  '${expense.category.name} · $spentOn',
                  style: secondary,
                ),
                // When it was added, if that's not the expense's own date.
                if (addedOn != spentOn)
                  Text(AppStrings.addedOnDate(addedOn), style: secondary),
                if (lastEdit != null && editor != null)
                  Text(
                    AppStrings.updatedByOn(
                      editor,
                      _date.format(lastEdit.createdAt.toLocal()),
                    ),
                    style: secondary,
                  ),
                if (expense.isPendingSync)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _SyncBadge(isDark: isDark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Pending sync" — saved on this phone, not on the server yet.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            AppStrings.pendingSync,
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
