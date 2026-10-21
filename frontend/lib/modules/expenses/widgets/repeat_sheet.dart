import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_repeat.dart';
import 'add_expense_sheet_header.dart';

/// "Repeat" bottom sheet of a new expense: Never / Every week / Every 2
/// weeks / Every month / Every year, plus an optional end date. Writes
/// straight into [addExpenseProvider]. [context] and [ref] are the
/// Add-expense screen's own.
void showRepeatSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
}) {
  showAdaptiveSheet<void>(
    context: context,
    size: AdaptiveSheetSize.small,
    // Above the floating tab bar.
    useRootNavigator: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RepeatSheetBody(isDark: isDark),
  );
}

class _RepeatSheetBody extends ConsumerWidget {
  const _RepeatSheetBody({required this.isDark});
  final bool isDark;

  void _set(WidgetRef ref, AddExpenseRepeat repeat) {
    final current = ref.read(addExpenseProvider);
    if (current.repeat == repeat) return;
    HapticService.instance.selection();
    ref.read(addExpenseProvider.notifier).state = current.copyWith(
      repeat: repeat,
    );
  }

  Future<void> _pickEndDate(BuildContext context, WidgetRef ref) async {
    final state = ref.read(addExpenseProvider);
    final first = DateUtils.dateOnly(state.date);
    final end = state.repeat.endDate;
    final picked = await showDatePicker(
      context: context,
      helpText: AppStrings.repeatPickEndDate,
      initialDate: end != null && !end.isBefore(first)
          ? end
          : DateTime(first.year + 1, first.month, first.day),
      firstDate: first,
      lastDate: DateTime(first.year + 10, first.month, first.day),
    );
    if (picked == null) return;
    _set(ref, ref.read(addExpenseProvider).repeat.withEndDate(picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addExpenseProvider);
    final repeat = state.repeat;
    final endError = repeatEndDateError(repeat, state.date);
    final options = <(String, AddExpenseRepeat)>[
      (AppStrings.repeatNever, AddExpenseRepeat.never),
      for (final f in RecurringFrequency.values)
        (f.label, AddExpenseRepeat(frequency: f, endDate: repeat.endDate)),
    ];
    final note =
        AppStrings.repeatFirstIsThis +
        (repeatStartsInPast(state.date)
            ? ' ${AppStrings.repeatPastDatesNote}'
            : '');

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AddExpenseSheetHandle(isDark: isDark)),
            AddExpenseSheetTitle(
              text: AppStrings.repeatRowLabel,
              isDark: isDark,
              trailing: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.repeatDone),
              ),
            ),
            for (final (label, value) in options)
              _RadioRow(
                isDark: isDark,
                label: label,
                selected: repeat.frequency == value.frequency,
                onTap: () => _set(ref, value),
              ),
            if (repeat.isOn) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                child: Text(
                  AppStrings.repeatEndsLabel,
                  style: AppTextStyles.caption(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ),
              _RadioRow(
                isDark: isDark,
                label: AppStrings.repeatNeverEnds,
                selected: repeat.endDate == null,
                onTap: () => _set(ref, repeat.withEndDate(null)),
              ),
              _RadioRow(
                isDark: isDark,
                label: repeat.endDate == null
                    ? AppStrings.repeatPickEndDate
                    : AppStrings.repeatEndsOn(
                        formatRepeatDate(repeat.endDate!),
                      ),
                selected: repeat.endDate != null,
                errorText: endError,
                onTap: () => _pickEndDate(context, ref),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Text(
                  note,
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
                ),
              ),
            ] else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// One choice in the sheet: label + radio mark, fully tappable.
class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.isDark,
    required this.label,
    required this.selected,
    required this.onTap,
    this.errorText,
  });

  final bool isDark;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final error = errorText;
    return Semantics(
      button: true,
      selected: selected,
      label: error == null ? label : '$label. $error',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body1(isDark).copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: selected
                        ? AppColors.tealDark
                        : AppColors.textSecondary(isDark),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(
                  error,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.errorText(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
