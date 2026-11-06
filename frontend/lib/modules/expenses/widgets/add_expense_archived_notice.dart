import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shown above the Add/Edit expense form when the chosen group is archived.
/// The save bar is disabled at the same time; payments can still be
/// recorded from the group's Balances tab.
class AddExpenseArchivedNotice extends StatelessWidget {
  const AddExpenseArchivedNotice({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: AppStrings.groupArchivedExpenseBlocked,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.archive_outlined,
              size: 20,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.groupArchivedExpenseBlocked,
                style: AppTextStyles.body2(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
