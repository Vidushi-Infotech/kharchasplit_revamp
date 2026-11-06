import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Empty state for a user whose every group is archived: still offers to
/// start a new one, while the archived section stays reachable below.
class NoActiveGroupsCard extends StatelessWidget {
  const NoActiveGroupsCard({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_add_outlined,
            size: 36,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.noActiveGroups,
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.noActiveGroupsHint,
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(AppStrings.createGroup),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
