import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/models.dart';
import '../state/add_expense_split_math.dart';
import 'add_expense_member_amount_row.dart';
import 'split_people_toggle.dart';

/// "By adjustment" split: equal shares, then + or − an amount per person
/// (e.g. +150 for Ravi's extra drink). Each row shows what that person ends
/// up owing, live. The maths is [adjustmentOwedPaise]; this widget only
/// owns the text fields.
class SplitAdjustmentBreakdown extends StatefulWidget {
  const SplitAdjustmentBreakdown({
    super.key,
    required this.totalAmount,
    required this.members,
    required this.adjustments,
    required this.includedMemberIds,
    required this.onAdjustmentsChanged,
    required this.onIncludedMembersChanged,
    this.currentUserId,
    this.currency = '₹',
  });

  final double totalAmount;

  /// Symbol the amounts are in (the form's entry currency).
  final String currency;
  final List<UserModel> members;
  final Map<String, double> adjustments;
  final Set<String> includedMemberIds;
  final ValueChanged<Map<String, double>> onAdjustmentsChanged;
  final ValueChanged<Set<String>> onIncludedMembersChanged;
  final String? currentUserId;

  @override
  State<SplitAdjustmentBreakdown> createState() =>
      _SplitAdjustmentBreakdownState();
}

class _SplitAdjustmentBreakdownState extends State<SplitAdjustmentBreakdown> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final m in widget.members) {
      final v = widget.adjustments[m.id] ?? 0;
      _controllers[m.id] = TextEditingController(
        text: v == 0
            ? ''
            : (v == v.roundToDouble()
                  ? v.toInt().toString()
                  : v.toStringAsFixed(2)),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _pushAdjustments() {
    widget.onAdjustmentsChanged({
      for (final m in widget.members)
        m.id: double.tryParse(_controllers[m.id]?.text.trim() ?? '') ?? 0,
    });
  }

  void _setIncluded(String id, bool included) {
    final next = {...widget.includedMemberIds};
    included ? next.add(id) : next.remove(id);
    widget.onIncludedMembersChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final owed = adjustmentOwedPaise(
      widget.totalAmount,
      widget.includedMemberIds,
      widget.adjustments,
    );
    final tooLarge = owed.values.any((p) => p < 0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              AppStrings.adjustmentHint,
              style: AppTextStyles.caption(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
          ),
          SplitPeopleToggle(
            members: widget.members,
            includedMemberIds: widget.includedMemberIds,
            onChanged: widget.onIncludedMembersChanged,
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.members.length,
            itemBuilder: (_, i) {
              final m = widget.members[i];
              final inSplit = widget.includedMemberIds.contains(m.id);
              final paise = owed[m.id];
              final name = m.id == widget.currentUserId
                  ? '${m.name} (Me)'
                  : m.name;
              return AddExpenseMemberAmountRow(
                member: m,
                label: name,
                controller: _controllers[m.id]!,
                fieldLabel: AppStrings.adjustmentFor(m.name),
                signed: true,
                currency: widget.currency,
                included: inSplit,
                onIncludedChanged: (v) => _setIncluded(m.id, v),
                onChanged: _pushAdjustments,
                caption: inSplit && paise != null
                    ? AppStrings.owesAmount(
                        CurrencyFormatter.format(
                          paise / 100,
                          currency: widget.currency,
                        ),
                      )
                    : AppStrings.notInThisSplit,
                captionColor: paise != null && paise < 0
                    ? AppColors.errorText(isDark)
                    : null,
              );
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              owed.isEmpty
                  ? AppStrings.nobodyInSplit
                  : tooLarge
                  ? AppStrings.adjustmentsTooLarge
                  : '✓ ${CurrencyFormatter.format(widget.totalAmount, currency: widget.currency)}',
              style: AppTextStyles.body2(isDark).copyWith(
                fontWeight: FontWeight.w700,
                color: owed.isEmpty || tooLarge
                    ? AppColors.errorText(isDark)
                    : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
