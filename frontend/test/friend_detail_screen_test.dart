import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/constants/app_strings.dart';
import 'package:kharchasplit/core/state/feature_flags_provider.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/auth/state/auth_provider.dart';
import 'package:kharchasplit/modules/friends/screens/friend_detail_screen.dart';
import 'package:kharchasplit/modules/friends/state/friend_detail_provider.dart';
import 'package:kharchasplit/modules/friends/state/friends_provider.dart';

UserModel _user(String id, String name) => UserModel(
      id: id,
      name: name,
      email: '',
      phone: '',
      createdAt: DateTime(2026),
    );

final _friend = FriendBalance(
  user: _user('f', 'Test Four'),
  net: 200,
  sharedGroupCount: 1,
  groups: const [
    FriendGroupBalance(
      groupId: 'g1',
      groupName: 'Settle Flow Test',
      currency: 'INR',
      net: 200,
    ),
  ],
);

ExpenseModel _dinner() => ExpenseModel(
      id: 'e1',
      title: 'Dinner',
      amount: 400,
      category: CategoryModel.other,
      paidBy: _user('me', 'Me'),
      payers: const [ExpensePayer(userId: 'me', name: 'Me', amount: 400)],
      splits: const [
        SplitModel(userId: 'me', userName: 'Me', owedShare: 200),
        SplitModel(userId: 'f', userName: 'Test Four', owedShare: 200),
      ],
      groupId: 'g1',
      date: DateTime(2026, 10, 18),
      createdAt: DateTime(2026, 10, 18),
    );

Future<void> _pump(
  WidgetTester tester,
  List<ExpenseModel> expenses, {
  FriendBalance? friend,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendsProvider.overrideWith((ref) async => [friend ?? _friend]),
        myIdProvider.overrideWithValue('me'),
        featureFlagsProvider.overrideWith((ref) async => <String>{}),
        friendSharedExpensesProvider.overrideWith((ref, id) async => expenses),
        friendGroupNamesProvider
            .overrideWith((ref, id) => {'g1': 'Settle Flow Test'}),
      ],
      child: const MaterialApp(home: FriendDetailScreen(friendId: 'f')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('banner, balance lines, chips, flat rows and FAB',
      (tester) async {
    await _pump(tester, [_dinner()]);

    expect(find.byTooltip(AppStrings.groupBack), findsOneWidget);
    expect(find.text('Test Four'), findsWidgets);
    expect(find.textContaining('Test Four owes you'), findsOneWidget);
    expect(
      find.textContaining('In Settle Flow Test, Test F. owes you'),
      findsOneWidget,
    );
    // They owe you: Remind…, no Settle up.
    expect(find.text(AppStrings.remindEllipsis), findsOneWidget);
    expect(find.text(AppStrings.settleUp), findsNothing);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.textContaining('Settle Flow Test · You paid'), findsOneWidget);
    expect(find.text(AppStrings.youLent), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('empty state when nothing is shared', (tester) async {
    await _pump(tester, const []);
    expect(find.text(AppStrings.friendNoSharedExpenses), findsOneWidget);
  });

  testWidgets('you owe them: orange Settle up, no Remind', (tester) async {
    await _pump(
      tester,
      const [],
      friend: FriendBalance(
        user: _user('f', 'Test Four'),
        net: -120,
        sharedGroupCount: 1,
        groups: const [
          FriendGroupBalance(
            groupId: 'g1',
            groupName: 'Settle Flow Test',
            currency: 'INR',
            net: -120,
          ),
        ],
      ),
    );
    expect(find.text(AppStrings.settleUp), findsOneWidget);
    expect(find.text(AppStrings.remindEllipsis), findsNothing);
    expect(find.textContaining('You owe Test Four'), findsOneWidget);
  });
}
