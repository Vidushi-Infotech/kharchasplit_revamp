import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/recurring/recurring_repository.dart';

/// The "Repeat" choice of a new expense: how often, and until when. Sent as
/// `repeat` with POST /expenses; the expense being added is the first
/// occurrence (on its own date) and the server creates the rest.
class AddExpenseRepeat {
  const AddExpenseRepeat({this.frequency, this.endDate});

  /// Doesn't repeat (the default).
  static const never = AddExpenseRepeat();

  /// null = never repeats.
  final RecurringFrequency? frequency;

  /// Last day it may repeat on (calendar day); null = never ends.
  final DateTime? endDate;

  bool get isOn => frequency != null;

  /// Same frequency, end date replaced (null = never ends).
  AddExpenseRepeat withEndDate(DateTime? endDate) =>
      AddExpenseRepeat(frequency: frequency, endDate: endDate);

  /// Request body for `repeat`, or null when it doesn't repeat.
  Map<String, dynamic>? toJson() {
    final f = frequency;
    if (f == null) return null;
    return {
      'frequency': f.apiValue,
      if (endDate != null) 'endDate': repeatDateOnly(endDate!),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AddExpenseRepeat &&
      other.frequency == frequency &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(frequency, endDate);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 'YYYY-MM-DD' of [d]'s calendar day, as the server expects.
String repeatDateOnly(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Value of the Repeat row: "Never", "Every month" or
/// "Every month · until 31 Mar 2027".
String repeatSummary(AddExpenseRepeat repeat) {
  final f = repeat.frequency;
  if (f == null) return AppStrings.repeatNever;
  final end = repeat.endDate;
  if (end == null) return f.label;
  return '${f.label} · ${AppStrings.repeatUntil(formatRepeatDate(end))}';
}

/// "31 Mar 2027".
String formatRepeatDate(DateTime d) => DateFormat('d MMM y').format(d);

/// Why the end date can't be used, or null. It must be on or after the
/// expense date (the first occurrence).
String? repeatEndDateError(AddExpenseRepeat repeat, DateTime expenseDate) {
  final end = repeat.endDate;
  if (!repeat.isOn || end == null) return null;
  return _day(end).isBefore(_day(expenseDate))
      ? AppStrings.repeatEndBeforeDate
      : null;
}

/// The expense date is before today: the server adds the missed dates
/// right away (up to 3).
bool repeatStartsInPast(DateTime expenseDate, {DateTime? now}) =>
    _day(expenseDate).isBefore(_day(now ?? DateTime.now()));
