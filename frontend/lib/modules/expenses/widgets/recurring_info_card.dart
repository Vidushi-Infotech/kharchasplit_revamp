import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../../../models/expense_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/recurring_rule_provider.dart';
import '../state/recurring_rule_text.dart';
import 'recurring_manage_flow.dart';

/// "Repeats every month · Next on 31 Dec" on the detail of an expense made
/// by a recurring rule (or Paused — reason / Ended / Stopped). The rule's
/// creator or a group admin also gets "Manage" while the `recurring` flag is
/// on; everyone else, and everyone when it's off, sees it read-only.
class RecurringInfoCard extends ConsumerWidget {
  const RecurringInfoCard({
    super.key,
    required this.expense,
    required this.isDark,
  });

  final ExpenseModel expense;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruleId = expense.recurringRuleId;
    if (ruleId == null) return const SizedBox.shrink();
    final ruleAsync = ref.watch(recurringRuleProvider(ruleId));
    final secondary = AppColors.textSecondary(isDark);

    return ruleAsync.when(
      loading: () => _shell(
        title: AppStrings.recurringBadge,
        subtitle: '…',
        subtitleColor: secondary,
      ),
      error: (_, _) => _shell(
        title: AppStrings.recurringBadge,
        subtitle: AppStrings.recurringLoadFailed,
        subtitleColor: secondary,
        trailing: TextButton(
          onPressed: () => ref.invalidate(recurringRuleProvider(ruleId)),
          child: const Text(AppStrings.retry),
        ),
      ),
      data: (rule) {
        // 404: someone chose "Stop repeating".
        if (rule == null) {
          return _shell(
            title: AppStrings.recurringStopped,
            subtitle: AppStrings.recurringStoppedHint,
            subtitleColor: secondary,
          );
        }
        final group = expense.groupId == null
            ? null
            : ref.watch(groupDetailProvider(expense.groupId!)).value?.group;
        final canManage =
            watchFeature(ref, 'recurring') &&
            canManageRecurringRule(
              rule: rule,
              myId: ref.watch(myIdProvider),
              group: group,
            );
        return _shell(
          title: recurringRepeatsLabel(rule.frequency),
          subtitle: recurringStatusText(rule),
          subtitleColor: rule.paused ? AppColors.warning : secondary,
          trailing: canManage ? _manageButton(context, ref, rule) : null,
        );
      },
    );
  }

  Widget _manageButton(BuildContext context, WidgetRef ref, RecurringRule r) {
    return Semantics(
      button: true,
      label: '${AppStrings.recurringManage} ${AppStrings.recurringBadge}',
      excludeSemantics: true,
      child: TextButton(
        onPressed: () => manageRecurringRule(context, ref, r),
        style: TextButton.styleFrom(foregroundColor: AppColors.tealDark),
        child: const Text(AppStrings.recurringManage),
      ),
    );
  }

  Widget _shell({
    required String title,
    required String subtitle,
    required Color subtitleColor,
    Widget? trailing,
  }) {
    return Semantics(
      container: true,
      label: '$title. $subtitle',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tealDark.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.repeat_rounded,
                size: 18,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption(
                        isDark,
                      ).copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
