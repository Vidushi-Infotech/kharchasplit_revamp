import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/personal_expense_model.dart';
import 'package:kharchasplit/models/personal_transfer_model.dart';
import 'package:kharchasplit/models/wallet_source_model.dart';
import 'package:kharchasplit/modules/personal_expenses/screens/personal_accounts_screen.dart';
import 'package:kharchasplit/modules/personal_expenses/state/wallet_provider.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/account_style.dart';

class _FakeWallet extends WalletNotifier {
  _FakeWallet(this.value);
  final WalletState value;

  @override
  Future<WalletState> build() async => value;
}

const _sources = [
  WalletSource(
    id: 'a',
    name: 'Cash',
    type: WalletSourceType.cash,
    balance: 3000,
    entryCount: 2,
  ),
  WalletSource(
    id: 'b',
    name: 'HDFC',
    type: WalletSourceType.bank,
    balance: 17700,
    entryCount: 1,
  ),
  WalletSource(
    id: 'c',
    name: 'Amex',
    type: WalletSourceType.card,
    balance: -1200,
  ),
];

void main() {
  test('account types from server and phone', () {
    final card = WalletSource.fromJson({
      'id': 'c',
      'name': 'Amex',
      'type': 'card',
      'balance': -1200,
      'entryCount': 4,
    });
    expect(card.type, WalletSourceType.card);
    expect(card.entryCount, 4);
    expect(card.toJson()['type'], 'card');
    // Phone-only wallets stored cash / bank; anything unknown is cash.
    expect(WalletSourceType.parse('bank'), WalletSourceType.bank);
    expect(WalletSourceType.parse('crypto'), WalletSourceType.cash);
    expect(accountBalanceText(card), '₹1,200.00 due');
    expect(accountBalanceText(_sources[0]), '₹3,000.00');
  });

  test('entries and transfers carry their account', () {
    final e = PersonalExpenseModel.fromJson({
      'id': 'e1',
      'description': 'Tea',
      'amount': '20',
      'account_id': 'a',
      'expense_date': '2026-10-30T10:00:00Z',
    });
    expect(e.accountId, 'a');
    final t = PersonalTransfer.fromJson({
      'id': 't1',
      'fromAccountId': 'b',
      'toAccountId': 'a',
      'amount': 2000,
      'note': 'ATM',
      'date': '2026-10-30T10:00:00.000Z',
    });
    expect(t.amount, 2000);
    expect(t.note, 'ATM');
  });

  testWidgets('accounts grouped by kind, with the total', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        walletProvider.overrideWith(
          () => _FakeWallet(const WalletState(
            sources: _sources,
            expenseSourceMap: {},
            onServer: true,
          )),
        ),
      ],
      child: const MaterialApp(home: PersonalAccountsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('₹19,500.00'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    for (final kind in ['CASH', 'BANK', 'CARD']) {
      expect(find.text(kind), findsOneWidget);
    }
    expect(find.text('₹1,200.00 due'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('1 entry'), findsOneWidget);
  });
}
