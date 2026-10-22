import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/list/list_components.dart';
import 'package:kharchasplit/core/theme/app_colors.dart';
import 'package:kharchasplit/core/utils/name_format.dart';

void main() {
  group('BalanceTone', () {
    test('picks the tone from the sign, half a paisa counts as settled', () {
      expect(BalanceTone.fromAmount(200), BalanceTone.owed);
      expect(BalanceTone.fromAmount(-0.5), BalanceTone.owe);
      expect(BalanceTone.fromAmount(0.004), BalanceTone.settled);
      expect(BalanceTone.fromAmount(-0.001), BalanceTone.settled);
    });

    test('labels for list rows and expense rows', () {
      expect(BalanceTone.owed.balanceLabel, 'you are owed');
      expect(BalanceTone.owe.balanceLabel, 'you owe');
      expect(BalanceTone.owed.expenseLabel, 'you lent');
      expect(BalanceTone.owe.expenseLabel, 'you borrowed');
      expect(BalanceTone.notInvolved.expenseLabel, 'not involved');
    });

    test('colors', () {
      expect(BalanceTone.owed.color(false), AppColors.owed);
      expect(BalanceTone.owe.color(true), AppColors.owe);
      expect(BalanceTone.settled.color(false), AppColors.settled);
    });
  });

  group('NameFormat.short', () {
    test('first name plus last initial', () {
      expect(NameFormat.short('Test Receiver'), 'Test R.');
      expect(NameFormat.short('  Shoaib  Ahmed  Ansari '), 'Shoaib A.');
    });

    test('single and blank names stay as they are', () {
      expect(NameFormat.short('Test'), 'Test');
      expect(NameFormat.short('  '), '');
    });
  });

  testWidgets('BalanceAmountLabel shows label and amount in one color',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BalanceAmountLabel(
          tone: BalanceTone.owe,
          amount: -500,
          forExpense: true,
        ),
      ),
    ));
    final label = tester.widget<Text>(find.text('you borrowed'));
    final amount = tester.widget<Text>(find.text('₹500.00'));
    expect(label.style?.color, AppColors.owe);
    expect(amount.style?.color, AppColors.owe);
  });

  testWidgets('settled rows show only the label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BalanceAmountLabel(tone: BalanceTone.settled, amount: 0),
      ),
    ));
    expect(find.text('settled up'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });
}
