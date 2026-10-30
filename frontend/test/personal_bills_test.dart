import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/personal_bill_model.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/bills/bill_row.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/bills/bill_style.dart';

PersonalBill _bill(int daysLeft, String status) => PersonalBill.fromJson({
  'id': 'b1',
  'name': 'Electricity',
  'amount': 1200,
  'category': 'utilities',
  'frequency': 'monthly',
  'nextDue': '2026-11-12',
  'daysLeft': daysLeft,
  'status': status,
  'remindDays': 2,
});

void main() {
  test('bill from the server', () {
    final b = _bill(-2, 'overdue');
    expect(b.frequency, BillFrequency.monthly);
    expect(b.status, BillStatus.overdue);
    expect(b.nextDue, DateTime(2026, 11, 12));
    expect(BillFrequency.parse('daily'), BillFrequency.monthly);
  });

  test('when it is due, in words', () {
    expect(billDueText(_bill(-1, 'overdue')), 'Overdue by 1 day');
    expect(billDueText(_bill(-3, 'overdue')), 'Overdue by 3 days');
    expect(billDueText(_bill(0, 'due')), 'Due today');
    expect(billDueText(_bill(1, 'due')), 'Due tomorrow');
    expect(billDueText(_bill(5, 'upcoming')), 'Due in 5 days');
    expect(billDueText(_bill(13, 'upcoming')), 'Due 12 Nov');
    expect(BillFrequency.biweekly.label, 'Every 2 weeks');
  });

  testWidgets('row shows the bill and pays on tap', (tester) async {
    var paid = 0;
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BillRow(
          bill: _bill(1, 'due'),
          onTap: () => opened++,
          onPay: () => paid++,
        ),
      ),
    ));
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Due tomorrow · Monthly'), findsOneWidget);
    expect(find.text('₹1,200.00'), findsOneWidget);
    await tester.tap(find.text('Pay'));
    await tester.tap(find.text('Electricity'));
    expect((paid, opened), (1, 1));
  });
}
