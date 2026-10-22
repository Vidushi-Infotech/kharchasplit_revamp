import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_provider.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_sentence.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_split_math.dart';
import 'package:kharchasplit/modules/expenses/state/expense_detail_lines.dart';
import 'package:kharchasplit/modules/expenses/state/split_summary_text.dart';
import 'package:kharchasplit/modules/expenses/widgets/add_expense_paid_split_line.dart';
import 'package:kharchasplit/modules/expenses/widgets/split_summary_bar.dart';

UserModel _user(String id, [String? name]) => UserModel(
  id: id,
  name: name ?? id,
  email: '',
  phone: '',
  createdAt: DateTime(2026),
);

final _members = [
  _user('me', 'Test Payer'),
  _user('r', 'Test Receiver'),
  _user('f', 'Test Friend'),
];

AddExpenseState _state({
  UserModel? paidBy,
  Map<String, double> payers = const {},
  SplitType splitType = SplitType.equal,
  bool adjustment = false,
  bool groupDefault = false,
}) => AddExpenseState(
  title: 'Dinner',
  amount: 1000,
  date: DateTime(2026, 10, 20),
  groupId: 'g',
  paidBy: paidBy,
  payers: payers,
  splitType: splitType,
  adjustmentMode: adjustment,
  usingGroupDefaultSplit: groupDefault,
);

ExpenseModel _expense({
  required List<ExpensePayer> payers,
  required Map<String, double> splits,
}) => ExpenseModel(
  id: 'e',
  title: 'Swiggy dinner',
  amount: 1000,
  category: CategoryModel.other,
  paidBy: _user(payers.first.userId, payers.first.name),
  payers: payers,
  splits: [
    for (final e in splits.entries)
      SplitModel(userId: e.key, userName: e.key, owedShare: e.value),
  ],
  date: DateTime(2026, 10, 20),
  createdAt: DateTime(2026, 10, 20),
);

void main() {
  group('Paid by … and split … sentence', () {
    test('defaults to you, equally', () {
      expect(
        addExpensePaidSplitSentence(_state(), _members, 'me'),
        'Paid by you and split equally.',
      );
    });

    test('someone else paid → short name', () {
      final s = _state(paidBy: _members[1], splitType: SplitType.exact);
      expect(
        addExpensePaidSplitSentence(s, _members, 'me'),
        'Paid by Test R. and split unequally.',
      );
    });

    test('several payers → "N people"', () {
      final s = _state(
        payers: const {'me': 400, 'r': 600},
        splitType: SplitType.percentage,
      );
      expect(addExpensePaidByPill(s, _members, 'me'), '2 people');
      expect(addExpenseSplitPill(s), 'by percentages');
    });

    test('one entry in payers is that person', () {
      final s = _state(payers: const {'f': 1000});
      expect(addExpensePaidByPill(s, _members, 'me'), 'Test F.');
    });

    test('shares, adjustment and the group default', () {
      expect(
        addExpenseSplitPill(_state(splitType: SplitType.shares)),
        'by shares',
      );
      expect(
        addExpenseSplitPill(
          _state(splitType: SplitType.exact, adjustment: true),
        ),
        'by adjustment',
      );
      expect(
        addExpenseSplitPill(
          _state(splitType: SplitType.percentage, groupDefault: true),
        ),
        'by group default',
      );
    });

    test('switching group keeps what was typed, drops member choices', () {
      final s = _state(
        payers: const {'me': 400, 'r': 600},
        splitType: SplitType.percentage,
      ).copyWith(notes: 'n', includedMemberIds: {'me'});
      final next = addExpenseStateForGroup(s, 'g2');
      expect(next.groupId, 'g2');
      expect(next.title, 'Dinner');
      expect(next.amount, 1000);
      expect(next.notes, 'n');
      expect(next.payers, isEmpty);
      expect(next.includedMemberIds, isEmpty);
      expect(next.splitMode, AddExpenseSplitMode.equal);
    });
  });

  group('expense detail per-person line', () {
    String line(bool isYou, double paid, double owes) => expensePersonLine(
      name: 'Test R.',
      isYou: isYou,
      paid: paid,
      owes: owes,
      currency: '₹',
    );

    test('paid and owes', () {
      expect(line(false, 600, 400), 'Test R. paid ₹600.00 and owes ₹400.00');
      expect(line(true, 400, 600), 'You paid ₹400.00 and owe ₹600.00');
    });

    test('only owes', () {
      expect(line(false, 0, 200), 'Test R. owes ₹200.00');
      expect(line(true, 0, 200), 'You owe ₹200.00');
    });

    test('only paid (not in the split)', () {
      expect(line(false, 1000, 0), 'Test R. paid ₹1,000.00');
      expect(line(true, 1000, 0), 'You paid ₹1,000.00');
    });

    test('people: payers first by amount, then the rest', () {
      final people = expensePeopleShares(
        _expense(
          payers: const [
            ExpensePayer(userId: 'me', name: 'Me', amount: 400),
            ExpensePayer(userId: 'r', name: 'R', amount: 600),
          ],
          splits: {'me': 600, 'r': 200, 'f': 200},
        ),
      );
      expect(people.map((p) => p.userId), ['r', 'me', 'f']);
      expect(people.first.paid, 600);
      expect(people.first.owes, 200);
      expect(people.last.paid, 0);
    });

    test('payer outside the split still gets a row', () {
      final people = expensePeopleShares(
        _expense(
          payers: const [ExpensePayer(userId: 'r', name: 'R', amount: 1000)],
          splits: {'me': 500, 'f': 500},
        ),
      );
      expect(people.map((p) => p.userId), ['r', 'me', 'f']);
      expect(people.first.split, isNull);
      expect(people.first.owes, 0);
    });
  });

  group('split options summary', () {
    test('equally: per person and head count', () {
      final s = splitOptionsSummary(
        mode: AddExpenseSplitMode.equal,
        amount: 1000,
        currency: '₹',
        people: 2,
      );
      expect(s.text, '₹500.00/person (2 people)');
      expect(s.balanced, isTrue);
    });

    test('exact: assigned of total, left / over', () {
      final left = splitOptionsSummary(
        mode: AddExpenseSplitMode.exact,
        amount: 500,
        currency: '₹',
        people: 2,
        assigned: 300,
      );
      expect(left.main, '₹300.00 of ₹500.00');
      expect(left.detail, '₹200.00 left');
      expect(left.balanced, isFalse);

      final over = splitOptionsSummary(
        mode: AddExpenseSplitMode.exact,
        amount: 500,
        currency: '₹',
        people: 2,
        assigned: 520,
      );
      expect(over.detail, '₹20.00 over');

      final exact = splitOptionsSummary(
        mode: AddExpenseSplitMode.exact,
        amount: 500,
        currency: '₹',
        people: 2,
        assigned: 500,
      );
      expect(exact.balanced, isTrue);
      expect(exact.detail, '₹0.00 left');
    });

    test('percentages', () {
      final s = splitOptionsSummary(
        mode: AddExpenseSplitMode.percentage,
        amount: 500,
        currency: '₹',
        people: 3,
        assigned: 66.7,
      );
      expect(s.text, '66.7% of 100% 33.3% left');
      expect(s.balanced, isFalse);
    });

    test('nobody in the split', () {
      final s = splitOptionsSummary(
        mode: AddExpenseSplitMode.adjustment,
        amount: 500,
        currency: '₹',
        people: 0,
      );
      expect(s.main, 'Select at least one person');
      expect(s.balanced, isFalse);
    });
  });

  group('widgets', () {
    testWidgets('paid/split line shows both pills and taps through', (
      tester,
    ) async {
      var paid = 0, split = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpensePaidSplitLine(
              isDark: false,
              state: _state(paidBy: _members[1]),
              groupMembers: _members,
              myId: 'me',
              showValidation: false,
              onPaidByTap: () => paid++,
              onSplitTap: () => split++,
            ),
          ),
        ),
      );
      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('Test R.'), findsOneWidget);
      expect(find.text('equally'), findsOneWidget);
      await tester.tap(find.text('Test R.'));
      await tester.tap(find.text('equally'));
      expect(paid, 1);
      expect(split, 1);
    });

    testWidgets('summary bar shows the All box for equal splits', (
      tester,
    ) async {
      bool? all;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplitSummaryBar(
              isDark: false,
              summary: splitOptionsSummary(
                mode: AddExpenseSplitMode.equal,
                amount: 1000,
                currency: '₹',
                people: 2,
              ),
              allSelected: true,
              onAllChanged: (v) => all = v,
            ),
          ),
        ),
      );
      expect(find.text('₹500.00/person'), findsOneWidget);
      expect(find.text('(2 people)'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      expect(all, isFalse);
    });
  });
}
