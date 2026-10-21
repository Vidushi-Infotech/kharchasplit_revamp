import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/expense_model.dart';
import 'expense_history_sheet.dart';

/// "Edit history" row on the expense detail screen — open to every member;
/// only people who can edit get "Restore this version" inside.
class ExpenseDetailHistoryRow extends StatelessWidget {
  const ExpenseDetailHistoryRow({
    super.key,
    required this.expense,
    required this.canEdit,
    required this.isDark,
  });

  final ExpenseModel expense;
  final bool canEdit;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.editHistory,
      child: Material(
        color: AppColors.cardBg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.divider(isDark)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showExpenseHistorySheet(
            context,
            expense: expense,
            canRestore: canEdit,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tealDark.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: AppColors.tealDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.editHistory,
                        style: AppTextStyles.body1(
                          isDark,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.editHistoryHint,
                        style: AppTextStyles.caption(
                          isDark,
                        ).copyWith(color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
