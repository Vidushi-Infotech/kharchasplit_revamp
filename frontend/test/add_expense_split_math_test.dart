import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/utils/split_calculator.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_category_suggest.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_provider.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_split_math.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_submit.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_validation.dart';

UserModel _user(String id) => UserModel(
  id: id,
  name: id,
  email: '',
  phone: '',
  createdAt: DateTime(2026),
);

AddExpenseState _state({
  double amount = 100,
  SplitType splitType = SplitType.equal,
  Map<String, double> splits = const {},
  Set<String> included = const {},
  bool adjustment = false,
  Map<String, double> adjustments = const {},
  Map<String, double> payers = const {},
}) => AddExpenseState(
  title: 't',
  amount: amount,
  date: DateTime(2026),
  groupId: 'g',
  splitType: splitType,
  splits: splits,
  includedMemberIds: included,
  adjustmentMode: adjustment,
  adjustments: adjustments,
  payers: payers,
);

int _sum(Iterable<int> v) => v.fold(0, (s, x) => s + x);

void main() {
  group('allocatePaise', () {
    test('equal: remainder goes to the first person', () {
      expect(SplitCalculator.allocatePaise(10000, [1, 1, 1]), [
        3334,
        3333,
        3333,
      ]);
    });

    test('weights always sum to the total', () {
      final out = SplitCalculator.allocatePaise(10001, [33.33, 33.33, 33.34]);
      expect(_sum(out), 10001);
      final shares = SplitCalculator.allocatePaise(9999, [1, 2, 3]);
      expect(_sum(shares), 9999);
    });

    test('zero weights get nothing', () {
      expect(SplitCalculator.allocatePaise(500, [0, 1, 0]), [0, 500, 0]);
      expect(SplitCalculator.allocatePaise(500, [0, 0]), [0, 0]);
    });
  });

  group('adjustmentPaise', () {
    test('Ravi had an extra ₹150 drink', () {
      // ₹1000, 3 people, +150 for the last: (1000 − 150) / 3 = 283.33…
      final out = SplitCalculator.adjustmentPaise(100000, [0, 0, 15000]);
      expect(out, [28334, 28333, 43333]);
      expect(_sum(out), 100000);
    });

    test('negative adjustments', () {
      final out = SplitCalculator.adjustmentPaise(10000, [-2000, 0]);
      expect(out, [4000, 6000]);
    });

    test('adjustments above the total floor correctly', () {
      // base = 100 − 120 = −20 → −10 each.
      expect(SplitCalculator.adjustmentPaise(100, [60, 60]), [50, 50]);
      // base = −7 over 2 → floor −4, remainder 1 to the first.
      final out = SplitCalculator.adjustmentPaise(100, [107, 0]);
      expect(_sum(out), 100);
      expect(out[1], -4);
    });
  });

  group('owed paise per split mode always matches the amount', () {
    const ids = ['a', 'b', 'c'];
    final cases = <String, AddExpenseState>{
      'equal': _state(amount: 100),
      'percentage': _state(
        amount: 100.01,
        splitType: SplitType.percentage,
        splits: {'a': 33.33, 'b': 33.33, 'c': 33.34},
      ),
      'shares': _state(
        amount: 99.99,
        splitType: SplitType.shares,
        splits: {'a': 1, 'b': 2, 'c': 4},
      ),
      'adjustment': _state(
        amount: 1000,
        splitType: SplitType.exact,
        adjustment: true,
        included: {'a', 'b', 'c'},
        adjustments: {'c': 150},
      ),
    };
    cases.forEach((name, state) {
      test(name, () {
        final owed = addExpenseOwedPaise(state, ids);
        expect(_sum(owed.values), SplitCalculator.toPaise(state.amount));
        final participants = buildExpenseParticipants(
          state,
          ids.map(_user).toList(),
          _user('a'),
        );
        final sent = _sum(
          participants.map((p) => SplitCalculator.toPaise(p.amount)),
        );
        expect(sent, SplitCalculator.toPaise(state.amount));
      });
    });
  });

  test('adjustment request: type, meta and final amounts', () {
    final state = _state(
      amount: 1000,
      splitType: SplitType.exact,
      adjustment: true,
      included: {'a', 'b'},
      adjustments: {'a': -100, 'c': 50},
    );
    final participants = buildExpenseParticipants(
      state,
      ['a', 'b', 'c'].map(_user).toList(),
      _user('a'),
    );
    expect(
      {for (final p in participants) p.userId: p.amount},
      {'a': 450.0, 'b': 550.0}, // (1000 + 100) / 2 = 550, then −100 for a
    );
    expect(backendSplitTypeFor(state), 'adjustment');
    expect(backendSplitMeta(state, participants), {
      'adjustments': {'a': -100.0, 'b': 0.0},
    });
    expect(state.isSplitValid, isTrue);
  });

  test('adjustments larger than the total are invalid', () {
    final state = _state(
      amount: 100,
      splitType: SplitType.exact,
      adjustment: true,
      included: {'a', 'b'},
      adjustments: {'a': 300},
    );
    expect(state.isSplitValid, isFalse);
  });

  test('exact split is checked to the paisa', () {
    final off = _state(
      amount: 100,
      splitType: SplitType.exact,
      splits: {'a': 50, 'b': 49.98},
    );
    expect(off.isSplitValid, isFalse);
    final ok = _state(
      amount: 100,
      splitType: SplitType.exact,
      splits: {'a': 50.01, 'b': 49.99},
    );
    expect(ok.isSplitValid, isTrue);
  });

  group('payers', () {
    test('single payer is sent as the whole amount', () {
      expect(addExpensePayersPaise(_state(amount: 12.5), 'me'), {'me': 1250});
    });

    test('multiple payers must add up exactly', () {
      final ok = _state(amount: 100, payers: {'a': 60.5, 'b': 39.5});
      expect(ok.isPayersValid, isTrue);
      expect(addExpensePayersPaise(ok, 'a'), {'a': 6050, 'b': 3950});

      // Amount changed after the payers were entered: flagged, not rescaled.
      final changed = ok.copyWith(amount: 120);
      expect(changed.isPayersValid, isFalse);
      expect(changed.isValid, isFalse);
      expect(payersLeftPaise(120, changed.payers), 2000);
      expect(changed.payersError, isNotNull);

      final over = _state(amount: 100, payers: {'a': 60, 'b': 40.01});
      expect(payersLeftPaise(100, over.payers), -1);
      expect(over.isPayersValid, isFalse);
    });

    test('saving one payer goes back to a single payer', () {
      final next = addExpenseWithPayers(
        _state(),
        {'a': 0, 'b': 100},
        [_user('a'), _user('b')],
      );
      expect(next.payers, isEmpty);
      expect(next.paidBy?.id, 'b');
    });
  });

  group('group default split', () {
    final members = [_user('a'), _user('b')];

    test('percentages skip ex-members and renormalise to 100', () {
      final d = groupDefaultSplitFor({
        'type': 'percentage',
        'values': {'a': 50, 'b': 30, 'gone': 20},
      }, members)!;
      expect(d.type, SplitType.percentage);
      expect(d.values, {'a': 62.5, 'b': 37.5});
    });

    test('renormalised percentages sum to exactly 100', () {
      final d = groupDefaultSplitFor(
        {
          'type': 'percentage',
          'values': {'a': 1, 'b': 1, 'c': 1},
        },
        [...members, _user('c')],
      )!;
      final total = d.values.values.fold<int>(
        0,
        (s, v) => s + (v * 100).round(),
      );
      expect(total, 10000);
    });

    test('shares keep their numbers; unknown types are ignored', () {
      final d = groupDefaultSplitFor({
        'type': 'shares',
        'values': {'a': 2},
      }, members)!;
      expect(d.values, {'a': 2.0});
      final state = addExpenseStateWithGroupDefault(_state(), {
        'type': 'shares',
        'values': {'a': 2},
      }, members)!;
      expect(state.splits, {'a': 2.0, 'b': 0.0});
      expect(state.includedMemberIds, {'a'});
      expect(state.usingGroupDefaultSplit, isTrue);
      expect(
        groupDefaultSplitFor({'type': 'equal', 'values': {}}, members),
        isNull,
      );
      expect(groupDefaultSplitFor(null, members), isNull);
    });
  });

  group('category keywords', () {
    test('maps common descriptions to existing categories', () {
      expect(categoryFromKeywords('Swiggy order'), CategoryModel.food);
      expect(categoryFromKeywords('dinner at the hotel'), CategoryModel.food);
      expect(categoryFromKeywords('Uber to airport'), CategoryModel.travel);
      expect(categoryFromKeywords('Petrol'), CategoryModel.fuel);
      expect(categoryFromKeywords('Flat rent'), CategoryModel.accommodation);
      expect(categoryFromKeywords('wifi bill'), CategoryModel.utilities);
      expect(categoryFromKeywords('Netflix'), CategoryModel.entertainment);
      expect(categoryFromKeywords('Blinkit groceries'), CategoryModel.shopping);
    });

    test('whole words only', () {
      expect(categoryFromKeywords("Parent's gift"), isNull);
      expect(knownCategory('nope'), isNull);
      expect(knownCategory('food'), CategoryModel.food);
    });
  });
}
