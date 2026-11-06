import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';

/// Explains why adding an expense is blocked. Used by the disabled
/// Add-expense FAB / button so the tap is never silent.
void showGroupArchivedNotice(BuildContext context) {
  HapticService.instance.error();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(AppStrings.groupArchivedExpenseBlocked),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shown at the top of group detail (all three layouts) while the group is
/// archived. Completed groups get the green "all settled up" variant.
/// Admins get an inline Unarchive button; payments stay available either
/// way, so nothing else is blocked here.
class GroupArchivedBanner extends StatelessWidget {
  const GroupArchivedBanner({
    super.key,
    required this.group,
    required this.isAdmin,
    required this.onUnarchive,
  });

  final GroupModel group;
  final bool isAdmin;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    if (!group.isArchived) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = group.isCompleted;
    final accent = completed ? AppColors.success : AppColors.warning;

    return Semantics(
      container: true,
      label: completed ? AppStrings.groupCompleted : AppStrings.groupArchived,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.task_alt_rounded : Icons.archive_outlined,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    completed
                        ? AppStrings.groupCompleted
                        : AppStrings.groupArchived,
                    style: AppTextStyles.body2(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.unarchiveToAddExpenses,
                    style: AppTextStyles.caption(
                      isDark,
                    ).copyWith(color: AppColors.textSecondary(isDark)),
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onUnarchive,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary(isDark),
                  side: BorderSide(color: AppColors.divider(isDark)),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(AppStrings.unarchive),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
