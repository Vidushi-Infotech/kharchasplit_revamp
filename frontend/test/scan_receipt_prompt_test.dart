import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/state/feature_flags_provider.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_provider.dart';
import 'package:kharchasplit/modules/expenses/widgets/scan_receipt_prompt.dart';

Widget _app({required bool isEditing, double amount = 0, VoidCallback? onTap}) =>
    ProviderScope(
      overrides: [
        featureFlagsProvider.overrideWith((ref) async => <String>{}),
        addExpenseProvider.overrideWith(
          (ref) => AddExpenseState(date: DateTime(2026, 10, 23), amount: amount),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ScanReceiptPrompt(isEditing: isEditing, onTap: onTap ?? () {}),
        ),
      ),
    );

void main() {
  testWidgets('shows on a new empty expense and opens the receipt sheet',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_app(isEditing: false, onTap: () => tapped++));
    await tester.pump();
    // Tests run off-device, so the scanner isn't available: the photo card.
    expect(find.text('Add a receipt'), findsOneWidget);
    await tester.tap(find.byType(ScanReceiptPrompt));
    expect(tapped, 1);
  });

  testWidgets('hidden once there is an amount, and when editing',
      (tester) async {
    await tester.pumpWidget(_app(isEditing: false, amount: 120));
    await tester.pump();
    expect(find.text('Add a receipt'), findsNothing);
    await tester.pumpWidget(_app(isEditing: true));
    await tester.pump();
    expect(find.text('Add a receipt'), findsNothing);
  });
}
