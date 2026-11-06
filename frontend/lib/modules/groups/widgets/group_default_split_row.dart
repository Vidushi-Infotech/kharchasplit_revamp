import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../state/group_detail_provider.dart';
import 'group_default_split_sheet.dart';

/// "Default split · By percentage" row in the Edit group sheet (admins
/// only, like the sheet itself; hidden for direct groups). Opens the editor.
class GroupDefaultSplitRow extends ConsumerWidget {
  const GroupDefaultSplitRow({super.key, required this.group});
  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (group.isDirect) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Reflects a save made from the editor while this sheet is open.
    final latest =
        ref.watch(groupDetailProvider(group.id)).value?.group ?? group;
    final current = switch (latest.defaultSplit?['type']) {
      'percentage' => AppStrings.splitPercentage,
      'shares' => AppStrings.splitShares,
      _ => AppStrings.equallyByDefault,
    };

    return Semantics(
      button: true,
      label: '${AppStrings.defaultSplit}: $current',
      child: Material(
        color: AppColors.cardBg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.divider(isDark)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showGroupDefaultSplitSheet(context, latest),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 18,
                  color: AppColors.tealDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.defaultSplit,
                    style: AppTextStyles.body2(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  current,
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
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
