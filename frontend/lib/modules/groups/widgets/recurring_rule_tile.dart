import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../../expenses/state/recurring_rule_text.dart';

/// One rule in the group's "Recurring expenses" list: description, amount,
/// how often, next date (or why it's paused) and who pays. [onTap] is null
/// for people who can't manage it — the row is then read-only.
class RecurringRuleTile extends StatelessWidget {
  const RecurringRuleTile({
    super.key,
    required this.rule,
    required this.payerNames,
    required this.isDark,
    this.onTap,
  });

  final RecurringRule rule;

  /// Display names of the payers, already resolved ("You", "Asha").
  final List<String> payerNames;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary(isDark);
    final currency = (rule.template['currency'] as String?) ?? 'INR';
    final amount = CurrencyFormatter.format(rule.amount, currency: currency);
    final status = recurringStatusText(rule);
    final paidBy = payerNames.isEmpty
        ? null
        : AppStrings.recurringPaidBy(payerNames.join(', '));
    final caption = AppTextStyles.caption(isDark).copyWith(color: secondary);

    return Semantics(
      button: onTap != null,
      label: [
        rule.description,
        amount,
        rule.frequency.label,
        status,
        ?paidBy,
      ].join('. '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.cardBg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.divider(isDark)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (rule.paused ? secondary : AppColors.tealDark)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    rule.paused ? Icons.pause_rounded : Icons.repeat_rounded,
                    size: 20,
                    color: rule.paused ? secondary : AppColors.tealDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body1(isDark).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            amount,
                            style: AppTextStyles.body1(
                              isDark,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(rule.frequency.label, style: caption),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: caption.copyWith(
                          color: rule.paused ? AppColors.warning : secondary,
                          fontWeight: rule.paused ? FontWeight.w600 : null,
                        ),
                      ),
                      if (paidBy != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          paidBy,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: caption,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: secondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
