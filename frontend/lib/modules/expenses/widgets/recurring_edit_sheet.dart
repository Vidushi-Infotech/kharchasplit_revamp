import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../state/recurring_rule_text.dart';

/// The changes picked in the sheet. Only fields that differ from the rule
/// are set; [clearEndDate] removes the end date.
typedef RecurringEdit = ({
  RecurringFrequency? frequency,
  String? endDate,
  bool clearEndDate,
});

/// "Change frequency or end date". Returns null when dismissed or nothing
/// changed.
Future<RecurringEdit?> showRecurringEditSheet(
  BuildContext context,
  RecurringRule rule,
) {
  return showAdaptiveSheet<RecurringEdit>(
    context: context,
    size: AdaptiveSheetSize.small,
    // Above the floating tab bar when opened from a tab-shell screen.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecurringEditSheet(rule: rule),
  );
}

class _RecurringEditSheet extends StatefulWidget {
  const _RecurringEditSheet({required this.rule});
  final RecurringRule rule;

  @override
  State<_RecurringEditSheet> createState() => _RecurringEditSheetState();
}

class _RecurringEditSheetState extends State<_RecurringEditSheet> {
  // Local form state only; saved through the caller's controller.
  late RecurringFrequency _frequency = widget.rule.frequency;
  late String? _endDate = widget.rule.endDate;

  Future<void> _pickEndDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final next = DateTime.tryParse(widget.rule.nextDate) ?? today;
    final first = next.isAfter(today) ? next : today;
    final current = _endDate == null ? null : DateTime.tryParse(_endDate!);
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime(first.year + 10),
      initialDate: current != null && !current.isBefore(first)
          ? current
          : first,
      helpText: AppStrings.recurringPickEndDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = DateFormat('yyyy-MM-dd').format(picked));
  }

  void _save() {
    final rule = widget.rule;
    final freqChanged = _frequency != rule.frequency;
    final endChanged = _endDate != rule.endDate;
    if (!freqChanged && !endChanged) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop<RecurringEdit>((
      frequency: freqChanged ? _frequency : null,
      endDate: endChanged ? _endDate : null,
      clearEndDate: endChanged && _endDate == null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = AppColors.textSecondary(isDark);
    final label = AppTextStyles.caption(isDark).copyWith(
      color: secondary,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );

    return Material(
      color: AppColors.background(isDark),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.recurringChange,
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 16),
              Text(AppStrings.recurringHowOften.toUpperCase(), style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in RecurringFrequency.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: f == _frequency,
                      selectedColor: AppColors.tealDark.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _frequency = f),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(AppStrings.recurringEndDate.toUpperCase(), style: label),
              const SizedBox(height: 6),
              Text(
                _endDate == null
                    ? AppStrings.recurringNoEndDate
                    : recurringShortDate(_endDate!),
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: const Text(AppStrings.recurringPickEndDate),
                  ),
                  if (_endDate != null)
                    TextButton(
                      onPressed: () => setState(() => _endDate = null),
                      child: const Text(AppStrings.recurringClearEndDate),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.tealDark,
                      ),
                      onPressed: _save,
                      child: const Text(AppStrings.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
