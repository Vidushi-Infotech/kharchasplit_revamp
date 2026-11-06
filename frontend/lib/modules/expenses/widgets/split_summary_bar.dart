import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/split_summary_text.dart';

/// Bottom bar of the Split options screen: "₹500.00/person (2 people)"
/// with an "All" box for equal splits, or "₹300.00 of ₹500.00 / ₹200.00
/// left" for exact amounts and percentages (red until it adds up).
class SplitSummaryBar extends StatelessWidget {
  const SplitSummaryBar({
    super.key,
    required this.isDark,
    required this.summary,
    this.allSelected,
    this.onAllChanged,
  });

  final bool isDark;
  final SplitSummary summary;

  /// Non-null shows the "All" box (equal split).
  final bool? allSelected;
  final ValueChanged<bool>? onAllChanged;

  @override
  Widget build(BuildContext context) {
    final color = summary.balanced
        ? AppColors.textPrimary(isDark)
        : AppColors.errorText(isDark);
    final all = allSelected;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          top: BorderSide(color: AppColors.divider(isDark), width: 0.6),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: summary.text,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.main,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w700, color: color),
                  ),
                  if (summary.detail != null)
                    Text(
                      summary.detail!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: summary.balanced
                            ? AppColors.textSecondary(isDark)
                            : color,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (all != null) ...[
            Container(
              width: 1,
              height: 32,
              color: AppColors.divider(isDark),
            ),
            const SizedBox(width: 8),
            Semantics(
              checked: all,
              label: AppStrings.selectAllShort,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onAllChanged?.call(!all),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.selectAllShort,
                        style: AppTextStyles.body2(
                          isDark,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Checkbox(
                        value: all,
                        activeColor: AppColors.tealDark,
                        onChanged: (v) => onAllChanged?.call(v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
