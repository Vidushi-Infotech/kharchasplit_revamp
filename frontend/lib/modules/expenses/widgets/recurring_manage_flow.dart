import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../state/recurring_rule_provider.dart';
import 'recurring_actions_sheet.dart';
import 'recurring_edit_sheet.dart';

/// Manage sheet → (confirm / edit sheet) → controller → SnackBar. Shared by
/// the expense detail card and the group's recurring list. Server errors
/// (403 not allowed, 409 CANNOT_RESUME) show their own sentence.
Future<void> manageRecurringRule(
  BuildContext context,
  WidgetRef ref,
  RecurringRule rule,
) async {
  final action = await showRecurringActionsSheet(context, rule);
  if (action == null || !context.mounted) return;

  final actions = ref.read(recurringRuleActionsProvider);
  final messenger = ScaffoldMessenger.of(context);
  late final Future<void> Function() run;

  switch (action) {
    case RecurringAction.pause:
      run = () => actions.pause(rule);
    case RecurringAction.resume:
      run = () => actions.resume(rule);
    case RecurringAction.stop:
      if (!await _confirmStop(context)) return;
      run = () => actions.stop(rule);
    case RecurringAction.edit:
      final edit = await showRecurringEditSheet(context, rule);
      if (edit == null) return;
      run = () => actions.update(
        rule,
        frequency: edit.frequency,
        endDate: edit.endDate,
        clearEndDate: edit.clearEndDate,
      );
  }

  try {
    await run();
    messenger.showSnackBar(
      SnackBar(content: Text(recurringDoneMessage(action))),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(recurringErrorMessage(e))));
  }
}

Future<bool> _confirmStop(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.recurringStopTitle),
      content: const Text(AppStrings.recurringStopBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.errorText(isDark),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(AppStrings.recurringStop),
        ),
      ],
    ),
  );
  return ok == true;
}
