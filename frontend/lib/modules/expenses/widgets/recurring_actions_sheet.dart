import 'package:flutter/material.dart';

import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../state/recurring_rule_provider.dart';
import '../state/recurring_rule_text.dart';

/// Pause / Resume, Change frequency or end date, Stop repeating — for
/// someone allowed to manage [rule]. Returns the picked action (null when
/// dismissed); the caller runs it.
Future<RecurringAction?> showRecurringActionsSheet(
  BuildContext context,
  RecurringRule rule,
) {
  return showAdaptiveSheet<RecurringAction>(
    context: context,
    size: AdaptiveSheetSize.small,
    // Above the floating tab bar when opened from a tab-shell screen.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecurringActionsSheet(rule: rule),
  );
}

class _RecurringActionsSheet extends StatelessWidget {
  const _RecurringActionsSheet({required this.rule});
  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    void pick(RecurringAction a) => Navigator.of(context).pop(a);

    return Material(
      color: AppColors.background(isDark),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  rule.description,
                  style: AppTextStyles.body1(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  recurringSummary(rule),
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
                ),
              ),
              const SizedBox(height: 10),
              if (rule.paused)
                _ActionRow(
                  icon: Icons.play_arrow_rounded,
                  label: AppStrings.recurringResume,
                  color: AppColors.textPrimary(isDark),
                  onTap: () => pick(RecurringAction.resume),
                )
              else
                _ActionRow(
                  icon: Icons.pause_rounded,
                  label: AppStrings.recurringPause,
                  color: AppColors.textPrimary(isDark),
                  onTap: () => pick(RecurringAction.pause),
                ),
              _ActionRow(
                icon: Icons.event_repeat_rounded,
                label: AppStrings.recurringChange,
                color: AppColors.textPrimary(isDark),
                onTap: () => pick(RecurringAction.edit),
              ),
              _ActionRow(
                icon: Icons.stop_circle_outlined,
                label: AppStrings.recurringStop,
                color: AppColors.errorText(isDark),
                onTap: () => pick(RecurringAction.stop),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}
