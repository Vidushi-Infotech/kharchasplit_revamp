import 'package:flutter/material.dart';

import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'add_expense_sheet_header.dart';

/// What a save of a recurring expense changes.
enum RepeatEditScope {
  /// Only this expense (PUT /expenses/:id).
  justThisOne,

  /// This expense and what its rule creates from now on.
  thisAndFuture,
}

/// Asks "Change just this expense, or this and future ones?" before saving
/// an edit of a recurring expense. null = cancelled (nothing is saved).
Future<RepeatEditScope?> askRepeatEditScope(
  BuildContext context, {
  required bool isDark,
}) {
  return showAdaptiveSheet<RepeatEditScope>(
    context: context,
    size: AdaptiveSheetSize.small,
    // Above the floating tab bar.
    useRootNavigator: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AddExpenseSheetHandle(isDark: isDark)),
            AddExpenseSheetTitle(
              text: AppStrings.repeatEditScopeTitle,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                AppStrings.repeatEditScopeHint,
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ),
            _ScopeOption(
              isDark: isDark,
              icon: Icons.event_note_outlined,
              label: AppStrings.repeatJustThisOne,
              onTap: () => Navigator.pop(ctx, RepeatEditScope.justThisOne),
            ),
            _ScopeOption(
              isDark: isDark,
              icon: Icons.event_repeat_rounded,
              label: AppStrings.repeatThisAndFuture,
              onTap: () => Navigator.pop(ctx, RepeatEditScope.thisAndFuture),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Semantics(
                button: true,
                label: AppStrings.cancel,
                excludeSemantics: true,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    AppStrings.cancel,
                    style: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: AppColors.cardBg(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.divider(isDark)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticService.instance.selection();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.tealDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary(isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
