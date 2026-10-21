import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "Using the group's default split" note on the split sheet, with a one-tap
/// way back to splitting equally.
class SplitDefaultHint extends StatelessWidget {
  const SplitDefaultHint({super.key, required this.onSplitEqually});

  final VoidCallback onSplitEqually;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.usingGroupDefaultSplit,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onSplitEqually,
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: const Text(AppStrings.splitEquallyInstead),
          ),
        ],
      ),
    );
  }
}
