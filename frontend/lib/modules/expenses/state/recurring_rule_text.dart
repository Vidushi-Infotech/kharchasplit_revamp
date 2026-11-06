import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../../../models/group_model.dart';

/// Pure display helpers for a [RecurringRule] — shared by the expense
/// detail card and the group's "Recurring expenses" list. No Flutter.

/// "Repeats every month".
String recurringRepeatsLabel(RecurringFrequency frequency) {
  final label = frequency.label;
  final lowered = label.isEmpty
      ? label
      : label[0].toLowerCase() + label.substring(1);
  return AppStrings.recurringRepeats(lowered);
}

/// 'YYYY-MM-DD' → "31 Dec" (this year) or "31 Dec 2027". Returns the raw
/// string when it can't be parsed.
String recurringShortDate(String ymd, {DateTime? now}) {
  final date = DateTime.tryParse(ymd);
  if (date == null) return ymd;
  final year = (now ?? DateTime.now()).year;
  return DateFormat(date.year == year ? 'd MMM' : 'd MMM yyyy').format(date);
}

/// Why a paused rule is paused, as shown to people: "Paused" (by hand),
/// "Ended" (past its end date) or "Paused — `reason`" (the server's sentence).
String recurringPauseLabel(String? reason) {
  final r = reason?.trim() ?? '';
  if (r == 'ended') return AppStrings.recurringEnded;
  if (r.isEmpty || r == 'paused') return AppStrings.recurringPaused;
  return AppStrings.recurringPausedBecause(r);
}

/// The status half of the summary: "Next on 31 Dec · Ends 31 Mar" for an
/// active rule, else the pause label.
String recurringStatusText(RecurringRule rule, {DateTime? now}) {
  if (rule.paused) return recurringPauseLabel(rule.pauseReason);
  final next = AppStrings.recurringNextOn(
    recurringShortDate(rule.nextDate, now: now),
  );
  final end = rule.endDate;
  if (end == null || end.isEmpty) return next;
  return '$next · ${AppStrings.recurringEndsOn(recurringShortDate(end, now: now))}';
}

/// "Repeats every month · Next on 31 Dec" / "Repeats every week · Paused".
String recurringSummary(RecurringRule rule, {DateTime? now}) =>
    '${recurringRepeatsLabel(rule.frequency)} · '
    '${recurringStatusText(rule, now: now)}';

/// Ids of the people who pay each time (template `payers`).
List<String> recurringPayerIds(RecurringRule rule) {
  final payers = rule.template['payers'];
  if (payers is! List) return const [];
  return [
    for (final p in payers)
      if (p is Map && p['userId'] is String) p['userId'] as String,
  ];
}

/// Server rule: only the person who set it up or a group admin (the group's
/// creator; a direct group has none) may pause / resume / edit / stop it.
bool canManageRecurringRule({
  required RecurringRule rule,
  required String? myId,
  required GroupModel? group,
}) {
  if (myId == null) return false;
  if (rule.createdBy == myId) return true;
  return group != null && !group.isDirect && group.createdBy == myId;
}
