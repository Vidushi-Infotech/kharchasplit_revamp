import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/category_model.dart';
import 'package:kharchasplit/models/personal_expense_model.dart';
import 'package:kharchasplit/modules/personal_expenses/state/personal_expenses_provider.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/entry_kind_toggle.dart';

PersonalExpenseModel _entry(String kind, num amount, String date,
        {String category = 'other'}) =>
    PersonalExpenseModel.fromJson({
      'id': '$kind-$amount-$date',
      'user_id': 'u1',
      'kind': kind,
      'description': 'x',
      'amount': '$amount',
      'currency': 'INR',
      'category': category,
      'expense_date': date,
      'created_at': date,
    });

void main() {
  test('kind from the server', () {
    final income = _entry('income', 5000, '2026-10-01T10:00:00Z',
        category: 'salary');
    expect(income.isIncome, isTrue);
    expect(income.signedAmount, 5000);
    expect(income.category, CategoryModel.salary);
    // Rows from a server without the column are expenses.
    final old = PersonalExpenseModel.fromJson({
      'id': 'a',
      'description': 'Tea',
      'amount': 20,
      'expense_date': '2026-10-01T10:00:00Z',
    });
    expect(old.isIncome, isFalse);
    expect(old.signedAmount, -20);
  });

  test('cash flow counts only the given month', () {
    final flow = CashFlow.of([
      _entry('income', 50000, '2026-10-01T10:00:00'),
      _entry('expense', 1200, '2026-10-05T10:00:00'),
      _entry('expense', 800.5, '2026-10-29T10:00:00'),
      _entry('expense', 999, '2026-09-30T10:00:00'),
      _entry('income', 7, '2025-10-10T10:00:00'),
    ], DateTime(2026, 10, 15));
    expect(flow.income, 50000);
    expect(flow.spent, 2000.5);
    expect(flow.net, 47999.5);
  });

  testWidgets('toggle reports the side tapped, not the current one',
      (tester) async {
    final picks = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EntryKindToggle(isIncome: false, onChanged: picks.add),
      ),
    ));
    await tester.tap(find.text('Expense'));
    await tester.tap(find.text('Income'));
    expect(picks, [true]);
  });
}
