import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/models.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_sentence.dart';
import '../state/add_expense_validation.dart';

/// "Paid by [you] and split [equally]." — one centred sentence whose two
/// parts are outlined pills: the first opens the paid-by sheet, the second
/// the split options. Payer / split problems show in red under it.
class AddExpensePaidSplitLine extends StatelessWidget {
  const AddExpensePaidSplitLine({
    super.key,
    required this.isDark,
    required this.state,
    required this.groupMembers,
    required this.myId,
    required this.showValidation,
    required this.onPaidByTap,
    required this.onSplitTap,
  });

  final bool isDark;
  final AddExpenseState state;
  final List<UserModel> groupMembers;
  final String? myId;
  final bool showValidation;
  final VoidCallback onPaidByTap;
  final VoidCallback onSplitTap;

  @override
  Widget build(BuildContext context) {
    final paidBy = addExpensePaidByPill(state, groupMembers, myId);
    final split = addExpenseSplitPill(state);
    final word = AppTextStyles.body1(
      isDark,
    ).copyWith(fontSize: 15, color: AppColors.textPrimary(isDark));
    // Payers are flagged straight away (the amount changed after they were
    // entered and we never rescale them silently); the split only after a
    // Save attempt, as before.
    final errors = <String>[
      ?state.payersError,
      if (showValidation && !state.isSplitValid)
        state.splitError ?? "Split doesn't add up",
    ];

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: [
            Text(AppStrings.paidByWord, style: word),
            _Pill(
              text: paidBy,
              isDark: isDark,
              error: state.payersError != null,
              semanticsLabel: AppStrings.changePayerLabel(paidBy),
              onTap: onPaidByTap,
            ),
            Text(AppStrings.andSplitWord, style: word),
            _Pill(
              text: split,
              isDark: isDark,
              error: showValidation && !state.isSplitValid,
              semanticsLabel: AppStrings.changeSplitLabel(split),
              onTap: onSplitTap,
            ),
            Text('.', style: word),
          ],
        ),
        for (final e in errors)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(
                e,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.errorText(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.isDark,
    required this.error,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String text;
  final bool isDark;
  final bool error;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.errorText(isDark) : AppColors.tealDark;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              text,
              style: AppTextStyles.body1(isDark).copyWith(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
