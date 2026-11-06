import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Small "Simplified" pill beside the Balances header when the group has
/// "Simplify group debts" on. Tap (or long-press / hover) explains why the
/// balances can differ from the expense-by-expense log.
class SimplifiedBalancesChip extends StatelessWidget {
  const SimplifiedBalancesChip({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: '${AppStrings.simplified}. ${AppStrings.simplifiedBalancesHint}',
      child: Tooltip(
        message: AppStrings.simplifiedBalancesHint,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_fix_high_rounded,
                size: 12,
                color: AppColors.brand,
              ),
              const SizedBox(width: 4),
              Text(
                AppStrings.simplified,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: isDark ? AppColors.tealLight : AppColors.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
