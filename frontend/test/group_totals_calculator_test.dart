import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/groups/state/group_totals_calculator.dart';

UserModel _user(String id) => UserModel(
  id: id,
  name: id.toUpperCase(),
  email: '',
  phone: '',
  createdAt: DateTime(2026),
);

ExpenseModel _expense(
  DateTime date, {
  required Map<String, double> payers,
  required Map<String, double> splits,
  CategoryModel category = CategoryModel.other,
  String? syncState,
}) => ExpenseModel(
  id: 'e${date.microsecondsSinceEpoch}',
  title: 't',
  amount: payers.values.fold(0, (s, v) => s + v),
  category: category,
  paidBy: _user(payers.keys.first),
  payers: [
    for (final p in payers.entries)
      ExpensePayer(userId: p.key, name: p.key.toUpperCase(), amount: p.value),
  ],
  splits: [
    for (final s in splits.entries)
      SplitModel(
        userId: s.key,
        userName: s.key.toUpperCase(),
        owedShare: s.value,
      ),
  ],
  date: date,
  createdAt: date,
  syncState: syncState,
);

SettlementModel _payment(
  String from,
  String to,
  double amount,
  DateTime date, {
  bool counts = true,
}) => SettlementModel(
  id: 's$from$to${date.day}',
  fromUser: _user(from),
  toUser: _user(to),
  amount: amount,
  date: date,
  createdAt: date,
  countsTowardBalance: counts,
);

GroupTotals _totals(
  List<ExpenseModel> expenses, {
  TotalsPeriod period = TotalsPeriod.allTime,
  DateTime? now,
  List<SettlementModel> settlements = const [],
  String myId = 'a',
}) => computeGroupTotals(
  expenses: expenses,
  settlements: settlements,
  members: [_user('a'), _user('b'), _user('c')],
  myId: myId,
  period: period,
  now: now ?? DateTime(2026, 10, 21, 12),
);

void main() {
  group('period boundaries (local time)', () {
    final now = DateTime(2026, 10, 21, 12);
    final lastSecondOfSeptember = DateTime(2026, 9, 30, 23, 59, 59);
    final firstOfOctober = DateTime(2026, 10, 1);
    final firstOfNovember = DateTime(2026, 11, 1);
    final expenses = [
      _expense(lastSecondOfSeptember, payers: {'a': 10}, splits: {'a': 10}),
      _expense(firstOfOctober, payers: {'a': 20}, splits: {'a': 20}),
      _expense(firstOfNovember, payers: {'a': 40}, splits: {'a': 40}),
    ];

    test('this month is [1 Oct, 1 Nov)', () {
      final t = _totals(expenses, period: TotalsPeriod.thisMonth, now: now);
      expect(t.totalSpending, 20);
      expect(t.expenseCount, 1);
      expect(t.months, isEmpty);
    });

    test('last month is September, including its last second', () {
      final t = _totals(expenses, period: TotalsPeriod.lastMonth, now: now);
      expect(t.totalSpending, 10);
    });

    test('last month in January is December of the previous year', () {
      final t = _totals(
        [
          _expense(
            DateTime(2025, 12, 31, 22),
            payers: {'a': 5},
            splits: {'a': 5},
          ),
        ],
        period: TotalsPeriod.lastMonth,
        now: DateTime(2026, 1, 3),
      );
      expect(t.totalSpending, 5);
    });

    test('this year includes Jan..Dec and has one bar per month to now', () {
      final t = _totals(expenses, period: TotalsPeriod.thisYear, now: now);
      expect(t.totalSpending, 70);
      expect(t.months.length, 10); // Jan..Oct
      expect(t.months.first.month, DateTime(2026, 1));
      expect(t.months.last.month, DateTime(2026, 10));
      expect(t.months[8].amount, 10); // September
      expect(t.months[9].amount, 20); // October (November is after "now")
    });

    test('a UTC timestamp is bucketed by its local date', () {
      final utc = DateTime.utc(2026, 10, 1, 0, 30);
      final t = _totals(
        [
          _expense(utc, payers: {'a': 7}, splits: {'a': 7}),
        ],
        period: TotalsPeriod.thisMonth,
        now: now,
      );
      final expected = utc.toLocal().month == 10 ? 7 : 0;
      expect(t.totalSpending, expected);
    });
  });

  test('all time: bars from the first month, capped at 12', () {
    final t = _totals([
      _expense(DateTime(2024, 1, 5), payers: {'a': 1}, splits: {'a': 1}),
      _expense(DateTime(2026, 9, 5), payers: {'a': 2}, splits: {'a': 2}),
    ]);
    expect(t.totalSpending, 3); // totals still include the old one
    expect(t.months.length, maxTotalsMonths);
    expect(t.months.last.month, DateTime(2026, 10));
    expect(t.months.first.month, DateTime(2025, 11));

    final short = _totals([
      _expense(DateTime(2026, 8, 5), payers: {'a': 1}, splits: {'a': 1}),
    ]);
    expect(short.months.map((m) => m.month.month), [8, 9, 10]);
  });

  test('multi-payer: what each paid comes from payers, not paidBy', () {
    final t = _totals([
      _expense(
        DateTime(2026, 10, 2),
        payers: {'b': 60, 'a': 40},
        splits: {'a': 50, 'b': 50},
      ),
    ]);
    expect(t.youPaid, 40);
    expect(t.yourShare, 50);
    final b = t.members.firstWhere((m) => m.userId == 'b');
    expect(b.paid, 60);
    expect(b.share, 50);
    expect(b.net, 10);
    expect(t.members.first.userId, 'b'); // biggest payer first
    // c is a member with nothing in the period: listed with zeros.
    final c = t.members.firstWhere((m) => m.userId == 'c');
    expect(c.paid, 0);
    expect(c.share, 0);
  });

  test('offline-pending expenses are excluded and counted', () {
    final t = _totals([
      _expense(
        DateTime(2026, 10, 2),
        payers: {'a': 100},
        splits: {'a': 50, 'b': 50},
      ),
      _expense(
        DateTime(2026, 10, 3),
        payers: {'a': 999},
        splits: {'a': 999},
        syncState: 'pending',
      ),
    ]);
    expect(t.totalSpending, 100);
    expect(t.expenseCount, 1);
    expect(t.pendingExcluded, 1);
  });

  test(
    'payments made / received only count paid settlements in the period',
    () {
      final t = _totals(
        const [],
        period: TotalsPeriod.thisMonth,
        settlements: [
          _payment('a', 'b', 30, DateTime(2026, 10, 5)),
          _payment('c', 'a', 12, DateTime(2026, 10, 6)),
          _payment(
            'a',
            'b',
            500,
            DateTime(2026, 10, 7),
            counts: false,
          ), // pending
          _payment('a', 'b', 70, DateTime(2026, 9, 7)), // last month
          _payment('b', 'c', 5, DateTime(2026, 10, 7)), // not mine
        ],
      );
      expect(t.paymentsMade, 30);
      expect(t.paymentsReceived, 12);
      expect(t.hasActivity, isTrue);
      expect(t.expenseCount, 0);
    },
  );

  test('categories: largest first with fractions of the total', () {
    final t = _totals([
      _expense(
        DateTime(2026, 10, 2),
        payers: {'a': 75},
        splits: {'a': 75},
        category: CategoryModel.food,
      ),
      _expense(
        DateTime(2026, 10, 3),
        payers: {'a': 25},
        splits: {'a': 25},
        category: CategoryModel.travel,
      ),
    ]);
    expect(t.categories.map((c) => c.category.id), ['food', 'travel']);
    expect(t.categories.first.fraction, closeTo(0.75, 1e-9));
  });

  test('former members on an expense still get a row', () {
    final t = _totals([
      _expense(
        DateTime(2026, 10, 2),
        payers: {'z': 30},
        splits: {'a': 15, 'z': 15},
      ),
    ]);
    final z = t.members.firstWhere((m) => m.userId == 'z');
    expect(z.name, 'Z');
    expect(z.paid, 30);
  });
}
