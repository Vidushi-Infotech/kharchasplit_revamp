import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/personal_budget_model.dart';
import 'package:kharchasplit/modules/personal_expenses/state/budget_alerts.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/budgets/budget_row.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/budgets/month_budget_card.dart';

BudgetsOverview _o(Map<String, (double, double)> budgets) => BudgetsOverview(
      month: DateTime(2026, 10),
      totalSpent: 0,
      budgets: [
        for (final e in budgets.entries)
          BudgetStatus(category: e.key, amount: e.value.$1, spent: e.value.$2),
      ],
      spent: const {},
    );

void main() {
  test('overview from the server', () {
    final o = BudgetsOverview.fromJson({
      'month': '2026-10',
      'totalSpent': 4100,
      'budgets': [
        {'category': 'food', 'amount': 4000, 'spent': 4100},
        {'category': 'total', 'amount': '20000', 'spent': 4100},
        {'category': 'fuel', 'amount': 2000, 'spent': 1700},
      ],
      'spent': [
        {'category': 'food', 'spent': 4100},
        {'category': 'shopping', 'spent': 99.5},
      ],
    });
    expect(o.total!.amount, 20000);
    expect(o.categories.map((b) => b.category), ['food', 'fuel']);
    expect(o.of('food')!.level, BudgetLevel.over);
    expect(o.of('fuel')!.level, BudgetLevel.near);
    expect(o.total!.level, BudgetLevel.fine);
    expect(o.spent['shopping'], 99.5);
  });

  test('alerts only when a budget moves up a level', () {
    final before = _o({'food': (1000, 700), 'total': (5000, 4500)});
    // 700 → 850: food reaches 85%; total was already near.
    var alerts = budgetAlerts(
      before,
      _o({'food': (1000, 850), 'total': (5000, 4650)}),
      'food',
    );
    expect(alerts.map((a) => (a.budget.category, a.level)), [
      ('food', BudgetLevel.near),
    ]);
    // Past 100% on both: the more serious first, then the month.
    alerts = budgetAlerts(
      _o({'food': (1000, 850), 'total': (5000, 4650)}),
      _o({'food': (1000, 1100), 'total': (5000, 5000)}),
      'food',
    );
    expect(alerts.map((a) => a.budget.category), ['food', 'total']);
    expect(alerts.every((a) => a.level == BudgetLevel.over), isTrue);
    // Already over: no repeat.
    expect(
      budgetAlerts(
        _o({'food': (1000, 1100)}),
        _o({'food': (1000, 1200)}),
        'food',
      ),
      isEmpty,
    );
    // Other categories' budgets don't alert.
    expect(
      budgetAlerts(null, _o({'fuel': (100, 500)}), 'food'),
      isEmpty,
    );
    expect(
      BudgetAlerts.message(alerts.first),
      'Food: ₹1,100.00 of ₹1,000.00 (110%)',
    );
  });

  testWidgets('budget row and month card', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          BudgetRow(
            budget: const BudgetStatus(
              category: 'food',
              amount: 1000,
              spent: 1250,
            ),
            onTap: () {},
          ),
          MonthBudgetCard(
            budget: const BudgetStatus(
              category: 'total',
              amount: 20000,
              spent: 5000,
            ),
            spent: 5000,
            onTap: () {},
          ),
          MonthBudgetCard(budget: null, spent: 0, onTap: () {}),
        ]),
      ),
    ));
    expect(find.text('₹250.00 over'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('₹15,000.00 left'), findsOneWidget);
    expect(find.text('Set a monthly budget'), findsOneWidget);
  });
}
