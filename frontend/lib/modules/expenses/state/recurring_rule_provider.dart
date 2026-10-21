import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/recurring/recurring_repository.dart';

/// One recurring rule by id. `null` means the rule is gone (404) — someone
/// chose "Stop repeating"; the expenses it created stay.
final recurringRuleProvider = FutureProvider.autoDispose
    .family<RecurringRule?, String>((ref, ruleId) async {
      try {
        return await ref.read(recurringRepositoryProvider).get(ruleId);
      } on RecurringApiException catch (e) {
        if (e.statusCode == 404) return null;
        rethrow;
      }
    });

/// The group's rules (active first, by next date — server order).
final groupRecurringRulesProvider = FutureProvider.autoDispose
    .family<List<RecurringRule>, String>(
      (ref, groupId) =>
          ref.read(recurringRepositoryProvider).listForGroup(groupId),
    );

/// What someone can do with a rule from the manage sheet.
enum RecurringAction { pause, resume, edit, stop }

/// Pause / resume / edit / stop, then refetch every view of the rule.
/// Errors are rethrown; turn them into text with [recurringErrorMessage].
class RecurringRuleActions {
  RecurringRuleActions(this._ref);
  final Ref _ref;

  RecurringRepository get _repo => _ref.read(recurringRepositoryProvider);

  Future<void> pause(RecurringRule rule) =>
      _run(rule, () => _repo.pause(rule.id));

  Future<void> resume(RecurringRule rule) =>
      _run(rule, () => _repo.resume(rule.id));

  Future<void> stop(RecurringRule rule) =>
      _run(rule, () => _repo.stop(rule.id));

  Future<void> update(
    RecurringRule rule, {
    RecurringFrequency? frequency,
    String? endDate,
    bool clearEndDate = false,
  }) => _run(
    rule,
    () => _repo.update(
      rule.id,
      frequency: frequency,
      endDate: endDate,
      clearEndDate: clearEndDate,
    ),
  );

  Future<void> _run(RecurringRule rule, Future<Object?> Function() call) async {
    try {
      await call();
    } finally {
      // Refresh even on failure: a 409 / 403 may mean our copy is stale.
      _ref.invalidate(recurringRuleProvider(rule.id));
      _ref.invalidate(groupRecurringRulesProvider(rule.groupId));
    }
  }
}

final recurringRuleActionsProvider = Provider<RecurringRuleActions>(
  RecurringRuleActions.new,
);

/// User-facing text for a failed action: the server's own sentence for API
/// errors (403 "Only the person who set it up…", 409 CANNOT_RESUME "Can't
/// resume: someone in it has left the group"), else a connection hint.
String recurringErrorMessage(Object error) {
  if (error is RecurringApiException && error.message.isNotEmpty) {
    return error.message;
  }
  return AppStrings.recurringActionFailed;
}

/// Snackbar text after a successful action.
String recurringDoneMessage(RecurringAction action) => switch (action) {
  RecurringAction.pause => AppStrings.recurringPausedDone,
  RecurringAction.resume => AppStrings.recurringResumedDone,
  RecurringAction.edit => AppStrings.recurringUpdatedDone,
  RecurringAction.stop => AppStrings.recurringStoppedDone,
};
