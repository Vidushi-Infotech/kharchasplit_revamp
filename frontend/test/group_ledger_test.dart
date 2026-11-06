import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/list/balance_tone.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/groups/state/group_ledger.dart';

UserModel _user(String id, [String? name]) => UserModel(
  id: id,
  name: name ?? id,
  email: '',
  phone: '',
  createdAt: DateTime(2026),
);

ExpenseModel _expense({
  required List<ExpensePayer> payers,
  required Map<String, double> splits,
  String id = 'e',
  DateTime? date,
}) => ExpenseModel(
  id: id,
  title: 'Dinner',
  amount: payers.fold(0, (s, p) => s + p.amount),
  category: CategoryModel.other,
  paidBy: _user(payers.first.userId, payers.first.name),
  payers: payers,
  splits: [
    for (final e in splits.entries)
      SplitModel(userId: e.key, userName: e.key, owedShare: e.value),
  ],
  date: date ?? DateTime(2026, 10, 18),
  createdAt: date ?? DateTime(2026, 10, 18),
);

void main() {
  group('expenseRowView', () {
    test('someone else paid, I am in the split → you borrowed my share', () {
      final view = expenseRowView(
        _expense(
          payers: const [
            ExpensePayer(userId: 'r', name: 'Test Receiver', amount: 1000),
          ],
          splits: {'me': 500, 'r': 500},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.owe);
      expect(view.tone.expenseLabel, 'you borrowed');
      expect(view.amount, closeTo(500, 1e-9));
      expect(view.payerLine, startsWith('Test R. paid'));
    });

    test('I paid for three → you lent the other two shares', () {
      final view = expenseRowView(
        _expense(
          payers: const [ExpensePayer(userId: 'me', name: 'Me', amount: 300)],
          splits: {'me': 100, 'b': 100, 'c': 100},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.owed);
      expect(view.tone.expenseLabel, 'you lent');
      expect(view.amount, closeTo(200, 1e-9));
      expect(view.payerLine, startsWith('You paid'));
    });

    test('multi-payer: paid more than my share → lent the difference', () {
      final view = expenseRowView(
        _expense(
          payers: const [
            ExpensePayer(userId: 'me', name: 'Me', amount: 60),
            ExpensePayer(userId: 'b', name: 'B', amount: 40),
          ],
          splits: {'me': 50, 'b': 50},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.owed);
      expect(view.amount, closeTo(10, 1e-9));
      expect(view.payerLine, startsWith('2 people paid'));
    });

    test('multi-payer: paid less than my share → borrowed (not "lent")', () {
      // The old card showed this amount green with an orange "You owe"
      // badge; label and amount now share one tone.
      final view = expenseRowView(
        _expense(
          payers: const [
            ExpensePayer(userId: 'me', name: 'Me', amount: 30),
            ExpensePayer(userId: 'b', name: 'B', amount: 70),
          ],
          splits: {'me': 50, 'b': 50},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.owe);
      expect(view.amount, closeTo(20, 1e-9));
    });

    test('neither paid nor in the split → not involved, no amount', () {
      final view = expenseRowView(
        _expense(
          payers: const [ExpensePayer(userId: 'b', name: 'B', amount: 100)],
          splits: {'b': 50, 'c': 50},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.notInvolved);
      expect(view.tone.expenseLabel, 'not involved');
      expect(view.amount, 0);
    });

    test('paid only for myself → involved but even (settled)', () {
      final view = expenseRowView(
        _expense(
          payers: const [ExpensePayer(userId: 'me', name: 'Me', amount: 80)],
          splits: {'me': 80},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.settled);
      expect(view.amount, closeTo(0, 1e-9));
    });

    test('signed-out viewer → not involved', () {
      final view = expenseRowView(
        _expense(
          payers: const [ExpensePayer(userId: 'b', name: 'B', amount: 100)],
          splits: {'b': 100},
        ),
        null,
      );
      expect(view.tone, BalanceTone.notInvolved);
    });
  });

  test('buildGroupLedger: newest first, payments inline, month headers', () {
    final payment = SettlementModel(
      id: 's',
      fromUser: _user('f', 'Test Friend'),
      toUser: _user('me'),
      amount: 200,
      date: DateTime(2026, 10, 20),
      createdAt: DateTime(2026, 10, 20),
    );
    final items = buildGroupLedger(
      expenses: [
        _expense(
          id: 'sep',
          payers: const [ExpensePayer(userId: 'me', name: 'Me', amount: 10)],
          splits: {'me': 10},
          date: DateTime(2026, 9, 5),
        ),
        _expense(
          id: 'oct',
          payers: const [ExpensePayer(userId: 'me', name: 'Me', amount: 10)],
          splits: {'me': 10},
          date: DateTime(2026, 10, 18),
        ),
      ],
      settlements: [payment],
    );
    expect(items.length, 5);
    expect((items[0] as LedgerMonthHeader).month, DateTime(2026, 10));
    expect((items[1] as LedgerPayment).settlement.id, 's');
    expect((items[2] as LedgerExpense).expense.id, 'oct');
    expect((items[3] as LedgerMonthHeader).month, DateTime(2026, 9));
    expect((items[4] as LedgerExpense).expense.id, 'sep');
    expect(paymentRowTitle(payment, 'me'), startsWith('Test F. paid you'));
  });
}
