import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/constants/app_strings.dart';
import 'package:kharchasplit/data/recurring/recurring_repository.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_provider.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_repeat.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_submit.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_validation.dart';
import 'package:kharchasplit/modules/expenses/state/expense_error_message.dart';

UserModel _user(String id) => UserModel(
  id: id,
  name: id,
  email: '',
  phone: '',
  createdAt: DateTime(2026),
);

const _monthly = AddExpenseRepeat(frequency: RecurringFrequency.monthly);

void main() {
  group('repeatSummary', () {
    test('never', () {
      expect(repeatSummary(AddExpenseRepeat.never), AppStrings.repeatNever);
    });
    test('frequency only', () {
      expect(repeatSummary(_monthly), 'Every month');
      expect(
        repeatSummary(
          const AddExpenseRepeat(frequency: RecurringFrequency.biweekly),
        ),
        'Every 2 weeks',
      );
    });
    test('with an end date', () {
      expect(
        repeatSummary(_monthly.withEndDate(DateTime(2027, 3, 31))),
        'Every month · until 31 Mar 2027',
      );
    });
  });

  group('toJson', () {
    test('null when it does not repeat', () {
      expect(AddExpenseRepeat.never.toJson(), isNull);
    });
    test('frequency and a YYYY-MM-DD end date', () {
      expect(_monthly.toJson(), {'frequency': 'monthly'});
      expect(
        const AddExpenseRepeat(
          frequency: RecurringFrequency.yearly,
        ).withEndDate(DateTime(2027, 1, 5, 18, 30)).toJson(),
        {'frequency': 'yearly', 'endDate': '2027-01-05'},
      );
    });
  });

  group('repeatEndDateError', () {
    final date = DateTime(2026, 10, 21, 15);
    test('no end date or not repeating → fine', () {
      expect(repeatEndDateError(_monthly, date), isNull);
      expect(
        repeatEndDateError(AddExpenseRepeat(endDate: DateTime(2020)), date),
        isNull,
      );
    });
    test('same day as the expense is allowed (any time of day)', () {
      expect(
        repeatEndDateError(_monthly.withEndDate(DateTime(2026, 10, 21)), date),
        isNull,
      );
    });
    test('before the expense date is an error', () {
      expect(
        repeatEndDateError(_monthly.withEndDate(DateTime(2026, 10, 20)), date),
        AppStrings.repeatEndBeforeDate,
      );
    });
    test('blocks the save', () {
      final s = AddExpenseState(
        title: 'Rent',
        amount: 100,
        date: date,
        repeat: _monthly.withEndDate(DateTime(2026, 9, 1)),
      );
      expect(s.repeatError, isNotNull);
      expect(s.isValid, isFalse);
      expect(s.copyWith(repeat: AddExpenseRepeat.never).isValid, isTrue);
    });
  });

  test('repeatStartsInPast compares calendar days', () {
    final now = DateTime(2026, 10, 21, 9);
    expect(repeatStartsInPast(DateTime(2026, 10, 21, 23), now: now), isFalse);
    expect(repeatStartsInPast(DateTime(2026, 10, 20, 23), now: now), isTrue);
  });

  test('copyWith keeps the recurring rule id', () {
    final s = AddExpenseState(date: DateTime(2026), recurringRuleId: 'r1');
    expect(s.copyWith(amount: 5).recurringRuleId, 'r1');
  });

  group('buildRecurringTemplate', () {
    test('same payload as the expense, to the paisa', () {
      final a = _user('a'), b = _user('b'), c = _user('c');
      final s = AddExpenseState(
        title: '  Rent ',
        amount: 100,
        currency: '₹',
        date: DateTime(2026),
        groupId: 'g',
        notes: '',
        includedMemberIds: const {'a', 'b', 'c'},
      );
      final participants = buildExpenseParticipants(s, [a, b, c], a);
      final t = buildRecurringTemplate(
        state: s,
        paidBy: a,
        participants: participants,
      );
      expect(t['description'], 'Rent');
      expect(t['amount'], 100);
      expect(t['currency'], 'INR');
      expect(t['category'], CategoryModel.other.id);
      expect(t['notes'], isNull);
      expect(t['splitType'], 'equal');
      expect(t['splitMeta'], isNull);
      expect(t['payers'], [
        {'userId': 'a', 'amount': 100},
      ]);
      final owed = (t['participants'] as List)
          .map((p) => ((p as Map)['amount'] as num) * 100)
          .fold<num>(0, (x, y) => x + y.round());
      expect(owed, 10000);
    });

    test('multiple payers and adjustment split', () {
      final a = _user('a'), b = _user('b');
      final s = AddExpenseState(
        title: 'Dinner',
        amount: 300,
        date: DateTime(2026),
        groupId: 'g',
        includedMemberIds: const {'a', 'b'},
        adjustmentMode: true,
        adjustments: const {'b': 50},
        payers: const {'a': 200, 'b': 100},
      );
      final participants = buildExpenseParticipants(s, [a, b], a);
      final t = buildRecurringTemplate(
        state: s,
        paidBy: a,
        participants: participants,
      );
      expect(t['splitType'], 'adjustment');
      expect(t['splitMeta'], {
        'adjustments': {'a': 0, 'b': 50},
      });
      expect(t['payers'], [
        {'userId': 'a', 'amount': 200},
        {'userId': 'b', 'amount': 100},
      ]);
      final byId = {
        for (final p in t['participants'] as List)
          (p as Map)['userId']: p['amount'],
      };
      expect(byId, {'a': 125, 'b': 175});
    });
  });

  group('recurringFutureErrorMessage', () {
    test('403 → only the creator can change future ones', () {
      expect(
        recurringFutureErrorMessage(
          RecurringApiException('Forbidden', statusCode: 403),
        ),
        AppStrings.repeatFutureForbidden,
      );
    });
    test('split mismatch keeps the expense wording', () {
      expect(
        recurringFutureErrorMessage(
          RecurringApiException('x', statusCode: 400, code: 'SPLIT_MISMATCH'),
        ),
        AppStrings.repeatFutureFailed(AppStrings.splitMismatch),
      );
    });
  });
}
