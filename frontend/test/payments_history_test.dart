import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/list/balance_tone.dart';
import 'package:kharchasplit/core/constants/app_strings.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/auth/state/auth_provider.dart';
import 'package:kharchasplit/modules/groups/state/group_detail_provider.dart';
import 'package:kharchasplit/modules/settlements/screens/settlement_history_screen.dart';
import 'package:kharchasplit/modules/settlements/state/payment_history_row_view.dart';
import 'package:kharchasplit/modules/settlements/state/payments_history_view.dart';
import 'package:kharchasplit/modules/settlements/widgets/not_received_button.dart';

UserModel _user(String id, String name) => UserModel(
  id: id,
  name: name,
  email: '',
  phone: '',
  createdAt: DateTime(2026),
);

final _me = _user('me', 'Test Payer');
final _four = _user('f', 'Test Four');

/// I paid [paid], split me / Test Four.
ExpenseModel _expense(double paid, double fourShare) => ExpenseModel(
  id: 'e$paid',
  title: 'Dinner',
  amount: paid,
  category: CategoryModel.other,
  paidBy: _me,
  payers: [ExpensePayer(userId: 'me', name: 'Test Payer', amount: paid)],
  splits: [
    SplitModel(
      userId: 'me',
      userName: 'Test Payer',
      owedShare: paid - fourShare,
    ),
    SplitModel(userId: 'f', userName: 'Test Four', owedShare: fourShare),
  ],
  groupId: 'g1',
  date: DateTime(2026, 10, 18),
  createdAt: DateTime(2026, 10, 18),
);

SettlementModel _payment({
  required UserModel from,
  required UserModel to,
  required double amount,
  String id = 's1',
  SettlementStatus status = SettlementStatus.completed,
  String? note,
  SettlementMethod? method,
}) => SettlementModel(
  id: id,
  fromUser: from,
  toUser: to,
  amount: amount,
  method: method,
  date: DateTime(2026, 10, 19, 9, 34),
  note: note,
  status: status,
  createdAt: DateTime(2026, 10, 19, 9, 34),
  countsTowardBalance: status == SettlementStatus.completed,
);

GroupDetail _detail({
  required List<ExpenseModel> expenses,
  required List<SettlementModel> settlements,
  bool fourIsMember = true,
}) {
  final members = [_me, if (fourIsMember) _four];
  return GroupDetail(
    group: GroupModel(
      id: 'g1',
      name: 'Settle Flow Test',
      coverEmoji: '',
      members: members,
      createdAt: DateTime(2026),
    ),
    members: members,
    expenses: expenses,
    settlements: settlements,
    totalExpense: 0,
  );
}

PaymentsHistoryView _view(GroupDetail d) =>
    buildPaymentsHistoryView(detail: d, myId: 'me', otherId: 'f');

void main() {
  group('header line', () {
    test('uses the group balance, not payments alone', () {
      // Test Four owed 400, paid 200 back: still owes 200. The old screen
      // said "You owe them ₹200" from the payment alone.
      final v = _view(
        _detail(
          expenses: [_expense(600, 400)],
          settlements: [_payment(from: _four, to: _me, amount: 200)],
        ),
      );
      expect(v.tone, BalanceTone.owed);
      expect(v.balance, closeTo(200, 1e-9));
      expect(
        paymentsHeaderLine(v),
        allOf(
          startsWith('Test F. owes you '),
          endsWith(' in Settle Flow Test'),
        ),
      );
      expect(paymentsHeaderLine(v), contains('200.00'));
      expect(v.toSettle, 0);
    });

    test('you owe them → "You owe Test F." and Settle up amount', () {
      final v = _view(
        _detail(
          expenses: [_expense(600, 400)],
          settlements: [_payment(from: _four, to: _me, amount: 600)],
        ),
      );
      expect(v.tone, BalanceTone.owe);
      expect(paymentsHeaderLine(v), startsWith('You owe Test F. '));
      expect(v.toSettle, closeTo(200, 1e-9));
    });

    test('pending payment of mine covers the debt → no Settle up', () {
      final v = _view(
        _detail(
          expenses: [_expense(600, 400)],
          settlements: [
            _payment(from: _four, to: _me, amount: 600),
            _payment(
              id: 's2',
              from: _me,
              to: _four,
              amount: 200,
              status: SettlementStatus.pending,
            ),
          ],
        ),
      );
      expect(v.toSettle, 0);
      expect(
        paymentsPendingLines(v),
        contains(AppStrings.historyCoveredByPending),
      );
    });

    test('settled', () {
      final v = _view(
        _detail(
          expenses: [_expense(400, 200)],
          settlements: [_payment(from: _four, to: _me, amount: 200)],
        ),
      );
      expect(v.tone, BalanceTone.settled);
      expect(
        paymentsHeaderLine(v),
        'You and Test F. are settled up in Settle Flow Test',
      );
    });

    test('former member keeps their name from expenses', () {
      final d = _detail(
        expenses: [_expense(600, 400)],
        settlements: const [],
        fourIsMember: false,
      );
      final v = _view(d);
      expect(v.otherName, 'Test Four');
      expect(v.otherIsMember, isFalse);
      expect(paymentsHeaderLine(v), startsWith('Test F. owes you'));
      expect(paymentsHeaderLine(v), isNot(contains('them')));
    });

    test('unknown person falls back to "Invited member"', () {
      final d = _detail(expenses: const [], settlements: const []);
      expect(resolvePersonName('zzz', d), AppStrings.invitedMember);
    });
  });

  group('payment row', () {
    test('received, confirmed, with method and note', () {
      final r = paymentHistoryRowView(
        _payment(
          from: _four,
          to: _me,
          amount: 200,
          method: SettlementMethod.cash,
          note: 'Written off: Test Four removed by admin',
        ),
        myId: 'me',
        otherName: 'Test Four',
      );
      expect(r.title, startsWith('Test F. paid you '));
      expect(r.when, '19 Oct 2026, 9:34 AM · Cash');
      expect(r.status, AppStrings.historyPaymentConfirmed);
      expect(r.note, 'Written off: Test Four removed by admin');
      expect(r.tone, BalanceTone.owed);
      expect(r.canMarkNotReceived, isTrue);
    });

    test('sent and pending: gray, waiting, no Not received', () {
      final r = paymentHistoryRowView(
        _payment(
          from: _me,
          to: _user('f', ''),
          amount: 50,
          status: SettlementStatus.pending,
        ),
        myId: 'me',
        otherName: 'Test Four',
      );
      // Blank name on the payment → resolved name, never "them".
      expect(r.title, startsWith('You paid Test F. '));
      expect(r.status, AppStrings.paymentAwaitingConfirmation);
      expect(r.statusKind, PaymentStatusKind.pending);
      expect(r.tone, BalanceTone.settled);
      expect(r.canMarkNotReceived, isFalse);
    });

    test('month grouping', () {
      final items = groupPaymentsByMonth([
        _payment(from: _four, to: _me, amount: 1),
      ]);
      expect(items.first, isA<PaymentMonthItem>());
      expect((items.first as PaymentMonthItem).title, 'October 2026');
      expect((items.last as PaymentRowItem).lastInMonth, isTrue);
    });
  });

  testWidgets('screen: header, actions, rows', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final detail = _detail(
      expenses: [_expense(600, 400)],
      settlements: [
        _payment(
          from: _four,
          to: _me,
          amount: 200,
          note: 'Written off: Test Four removed by admin',
        ),
      ],
      fourIsMember: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myIdProvider.overrideWithValue('me'),
          groupDetailProvider.overrideWith((ref, id) async => detail),
        ],
        child: const MaterialApp(
          home: SettlementHistoryScreen(groupId: 'g1', otherUserId: 'f'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text(AppStrings.payments), findsOneWidget);
    expect(find.text('Settle Flow Test'), findsOneWidget);
    expect(find.textContaining('Test F. owes you'), findsOneWidget);
    expect(find.textContaining('Member'), findsNothing);
    // They owe me but left the group: no Settle up, no Remind.
    expect(find.text(AppStrings.settleUp), findsNothing);
    expect(find.text(AppStrings.remindEllipsis), findsNothing);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.textContaining('Test F. paid you'), findsOneWidget);
    expect(
      find.text('Written off: Test Four removed by admin'),
      findsOneWidget,
    );
    expect(find.byType(NotReceivedButton), findsOneWidget);
  });
}
