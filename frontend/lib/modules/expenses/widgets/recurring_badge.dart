import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Small "🔁 Recurring" marker for expenses created by a recurring rule.
/// [compact] shows only the repeat icon (tight rows such as the activity
/// feed); screen readers still hear "Recurring".
class RecurringBadge extends StatelessWidget {
  const RecurringBadge({super.key, required this.isDark, this.compact = false});

  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.tealDark;
    const icon = Icons.repeat_rounded;
    if (compact) {
      return Semantics(
        label: AppStrings.recurringBadge,
        child: Icon(icon, size: 12, color: color),
      );
    }
    return Semantics(
      label: AppStrings.recurringBadge,
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
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              AppStrings.recurringBadge,
              style: AppTextStyles.caption(isDark).copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
