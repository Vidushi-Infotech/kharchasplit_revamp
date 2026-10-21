import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "Pending sync" (waiting in the offline outbox) or "Not synced" (the
/// server refused it — see Unsynced changes) on an expense.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.isDark, required this.failed});

  final bool isDark;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed ? AppColors.errorText(isDark) : AppColors.warning;
    final label = failed ? AppStrings.notSynced : AppStrings.pendingSync;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.sync_problem_rounded : Icons.cloud_upload_outlined,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTextStyles.caption(isDark).copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
