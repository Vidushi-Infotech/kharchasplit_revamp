import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/state/feature_flags_provider.dart';
import 'package:kharchasplit/models/group_model.dart';
import 'package:kharchasplit/models/personal_expense_model.dart';
import 'package:kharchasplit/models/wallet_source_model.dart';
import 'package:kharchasplit/modules/personal_expenses/screens/add_personal_expense_screen.dart';
import 'package:kharchasplit/modules/personal_expenses/state/personal_expenses_provider.dart';
import 'package:kharchasplit/modules/personal_expenses/state/wallet_provider.dart';

final _entry = PersonalExpenseModel.fromJson({
  'id': 'e1',
  'kind': 'income',
  'description': 'Salary',
  'amount': '50000',
  'category': 'salary',
  'account_id': 'hdfc',
  'expense_date': '2026-10-01T10:00:00Z',
});

class _Entries extends PersonalExpensesNotifier {
  @override
  Future<List<PersonalExpenseModel>> build() async => [_entry];
}

class _Wallet extends WalletNotifier {
  @override
  Future<WalletState> build() async => const WalletState(
    sources: [
      WalletSource(id: 'cash', name: 'Cash', type: WalletSourceType.cash, balance: 0),
      WalletSource(id: 'hdfc', name: 'HDFC', type: WalletSourceType.bank, balance: 0),
    ],
    expenseSourceMap: {},
    onServer: true,
  );
}

Widget _app(String id) => ProviderScope(
  overrides: [
    personalExpensesProvider.overrideWith(_Entries.new),
    walletProvider.overrideWith(_Wallet.new),
    featureFlagsProvider.overrideWith((ref) async => {'personalIncome'}),
  ],
  child: MaterialApp(home: EditPersonalEntryScreen(entryId: id)),
);

void main() {
  testWidgets('an entry opens filled in, as income', (tester) async {
    await tester.pumpWidget(_app('e1'));
    await tester.pumpAndSettle();
    expect(find.text('Edit income'), findsOneWidget);
    expect(find.text('Salary'), findsWidgets);
    expect(find.text('50000'), findsOneWidget);
    expect(find.text('Received in'), findsOneWidget);
  });

  testWidgets('a missing entry says so', (tester) async {
    await tester.pumpWidget(_app('nope'));
    await tester.pumpAndSettle();
    expect(find.text('This entry is no longer here.'), findsOneWidget);
  });

  test('group notes come from the server', () {
    final g = GroupModel.fromJson({
      'id': 'g',
      'name': 'Goa',
      'description': 'Dec trip',
      'created_at': '2026-10-01T00:00:00Z',
    });
    expect(g.description, 'Dec trip');
    expect(
      GroupModel.fromJson({'id': 'g', 'name': 'x', 'description': '  '})
          .description,
      isNull,
    );
  });
}
