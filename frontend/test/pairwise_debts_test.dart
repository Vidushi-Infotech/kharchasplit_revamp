import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/groups/state/group_detail_provider.dart';

UserModel _user(String id) =>
    UserModel(id: id, name: id, email: '', phone: '', createdAt: DateTime(2026));

ExpenseModel _expense({
  required List<ExpensePayer> payers,
  required Map<String, double> splits,
}) =>
    ExpenseModel(
      id: 'e',
      title: 't',
      amount: payers.fold(0, (s, p) => s + p.amount),
      category: CategoryModel.other,
      paidBy: _user(payers.first.userId),
      payers: payers,
      splits: [
        for (final e in splits.entries)
          SplitModel(userId: e.key, userName: e.key, owedShare: e.value),
      ],
      date: DateTime(2026),
      createdAt: DateTime(2026),
    );

void main() {
  test('one payer: the other side owes their whole share', () {
    final pair = computePairwiseDebts(
      myId: 'a',
      expenses: [
        _expense(
          payers: const [ExpensePayer(userId: 'b', name: 'b', amount: 100)],
          splits: {'a': 50, 'b': 50},
        ),
      ],
      settlements: const [],
    );
    expect(pair['b'], closeTo(50, 1e-9)); // a owes b 50
  });

  test('two payers: debts follow what each paid (60/40, split 50/50)', () {
    final expense = _expense(
      payers: const [
        ExpensePayer(userId: 'a', name: 'a', amount: 60),
        ExpensePayer(userId: 'b', name: 'b', amount: 40),
      ],
      splits: {'a': 50, 'b': 50},
    );
    final forA = computePairwiseDebts(myId: 'a', expenses: [expense], settlements: const []);
    final forB = computePairwiseDebts(myId: 'b', expenses: [expense], settlements: const []);
    expect(forA['b'], closeTo(-10, 1e-9)); // b owes a 10
    expect(forB['a'], closeTo(10, 1e-9));
  });

  test('three people, two payers: nets match paid − share', () {
    final expense = _expense(
      payers: const [
        ExpensePayer(userId: 'a', name: 'a', amount: 90),
        ExpensePayer(userId: 'b', name: 'b', amount: 30),
      ],
      splits: {'a': 40, 'b': 40, 'c': 40},
    );
    double net(String id) => -computePairwiseDebts(
          myId: id,
          expenses: [expense],
          settlements: const [],
        ).values.fold<double>(0, (s, v) => s + v);
    expect(net('a'), closeTo(50, 1e-9));
    expect(net('b'), closeTo(-10, 1e-9));
    expect(net('c'), closeTo(-40, 1e-9));
  });
}
