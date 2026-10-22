import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/list/balance_tone.dart';
import 'package:kharchasplit/core/constants/app_strings.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/expenses/widgets/split_member_row.dart';
import 'package:kharchasplit/modules/friends/state/friend_detail_view.dart';
import 'package:kharchasplit/modules/friends/state/friends_provider.dart';
import 'package:kharchasplit/modules/groups/state/group_totals_calculator.dart';
import 'package:kharchasplit/modules/groups/widgets/group_totals_members.dart';

UserModel _user(String id, [String? name]) => UserModel(
      id: id,
      name: name ?? id,
      email: '',
      phone: '',
      createdAt: DateTime(2026),
    );

ExpenseModel _expense({
  required List<ExpensePayer> payers,
  required Map<String, double> splits,
}) =>
    ExpenseModel(
      id: 'e',
      title: 'Dinner',
      amount: payers.fold(0, (s, p) => s + p.amount),
      category: CategoryModel.other,
      paidBy: _user(payers.first.userId, payers.first.name),
      payers: payers,
      splits: [
        for (final e in splits.entries)
          SplitModel(userId: e.key, userName: e.key, owedShare: e.value),
      ],
      date: DateTime(2026, 10, 18),
      createdAt: DateTime(2026, 10, 18),
    );

FriendBalance _friend(List<FriendGroupBalance> groups, {String? name}) =>
    FriendBalance(
      user: _user('f', name ?? 'Test Four'),
      net: groups.fold(0, (s, g) => s + g.net),
      sharedGroupCount: groups.length,
      groups: groups,
    );

void main() {
  group('friendExpenseRowView', () {
    test('friend paid, I am in the split → one orange "you borrowed"', () {
      final view = friendExpenseRowView(
        _expense(
          payers: const [
            ExpensePayer(userId: 'f', name: 'Test Four', amount: 900),
          ],
          splits: {'me': 450, 'f': 450},
        ),
        'me',
        groupName: 'Settle Flow Test',
      );
      expect(view.tone, BalanceTone.owe);
      expect(view.label, AppStrings.youBorrowed);
      expect(view.amount, closeTo(450, 1e-9));
      expect(view.showsAmount, isTrue);
      expect(view.subtitle, startsWith('Settle Flow Test · Test F. paid'));
    });

    test('I paid → green "you lent"; non-group rows show only the payer', () {
      final view = friendExpenseRowView(
        _expense(
          payers: const [ExpensePayer(userId: 'me', name: 'Me', amount: 300)],
          splits: {'me': 150, 'f': 150},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.owed);
      expect(view.label, AppStrings.youLent);
      expect(view.amount, closeTo(150, 1e-9));
      expect(view.subtitle, startsWith('You paid'));
    });

    test('not in the split and did not pay → gray "not involved"', () {
      final view = friendExpenseRowView(
        _expense(
          payers: const [ExpensePayer(userId: 'f', name: 'F', amount: 100)],
          splits: {'f': 50, 'x': 50},
        ),
        'me',
      );
      expect(view.tone, BalanceTone.notInvolved);
      expect(view.label, AppStrings.notInvolved);
      expect(view.showsAmount, isFalse);
    });
  });

  group('friend header lines', () {
    test('overall line per currency and per-group lines', () {
      final f = _friend(const [
        FriendGroupBalance(
          groupId: 'g1',
          groupName: 'Settle Flow Test',
          currency: 'INR',
          net: 200,
        ),
        FriendGroupBalance(
          groupId: 'd',
          groupName: '',
          currency: 'INR',
          net: -50,
          isDirect: true,
        ),
      ]);
      final overall = friendOverallLines(f);
      expect(overall, hasLength(1));
      expect(overall.single.tone, BalanceTone.owed);
      expect(overall.single.text, startsWith('Test Four owes you'));
      expect(overall.single.text, endsWith('overall'));
      expect(
        friendGroupLine(f.groups[0], f.user.name),
        startsWith('In Settle Flow Test, Test F. owes you'),
      );
      expect(
        friendGroupLine(f.groups[1], f.user.name),
        startsWith('In non-group expenses, you owe Test F.'),
      );
    });

    test('settled friend and nameless invitee', () {
      final lines = friendOverallLines(_friend(const [], name: ' '));
      expect(lines.single.tone, BalanceTone.settled);
      expect(lines.single.text, AppStrings.settledUpWith(AppStrings.invitedMember));
    });
  });

  group('totals member row text', () {
    const member = MemberTotal(
      userId: 'r',
      name: 'Test Receiver',
      paid: 1900,
      share: 950,
    );

    test('paid and share on one gray line', () {
      final line = totalsMemberLine(member, '₹');
      expect(line, startsWith('Paid ₹'));
      expect(line, contains(' · Share ₹'));
      expect(line, contains('1,900.00'));
      expect(line, contains('950.00'));
    });

    test('tone label and invited fallback', () {
      expect(totalsMemberLabel(BalanceTone.fromAmount(member.net)), 'gets back');
      expect(totalsMemberLabel(BalanceTone.fromAmount(-600)), 'owes');
      const nameless = MemberTotal(userId: 'x', name: '', paid: 0, share: 10);
      expect(
        totalsMemberName(nameless, isMe: false),
        AppStrings.invitedMember,
      );
      expect(totalsMemberName(member, isMe: true), 'Test Receiver (you)');
    });
  });

  testWidgets('equal split shows the share as text, not a field',
      (tester) async {
    final controller = TextEditingController(text: '450');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SplitMemberRow(
            member: _user('x', ''),
            controller: controller,
            included: true,
            value: 450,
            splitType: SplitType.equal,
            totalAmount: 900,
            currency: '₹',
            isMe: false,
            onToggle: () {},
            onChanged: () {},
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('₹450.00'), findsOneWidget);
    expect(find.text(AppStrings.invitedMember), findsOneWidget);
  });
}
