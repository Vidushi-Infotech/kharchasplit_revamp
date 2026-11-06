import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/data/friends/friends_repository.dart';
import 'package:kharchasplit/models/group_model.dart';
import 'package:kharchasplit/models/user_model.dart';
import 'package:kharchasplit/modules/friends/state/friend_lines.dart';
import 'package:kharchasplit/modules/friends/widgets/friend_list_tile.dart';
import 'package:kharchasplit/modules/groups/state/groups_list_view.dart';
import 'package:kharchasplit/modules/groups/widgets/group_row_card.dart';

FriendBalance _friend(String name, List<FriendGroupBalance> groups) =>
    FriendBalance(
      user: UserModel(
        id: name,
        name: name,
        email: '',
        phone: '',
        createdAt: DateTime(2026),
      ),
      net: groups.fold(0, (s, g) => s + g.net),
      sharedGroupCount: groups.length,
      groups: groups,
    );

FriendGroupBalance _in(String id, double net, {bool direct = false}) =>
    FriendGroupBalance(
      groupId: id,
      groupName: id == 'g1' ? 'Goa Trip' : 'Flat',
      currency: 'INR',
      net: net,
      isDirect: direct,
    );

GroupModel _group(String id, double balance, {bool simplify = false}) =>
    GroupModel(
      id: id,
      name: id,
      coverEmoji: '👥',
      members: const [],
      myBalance: balance,
      createdAt: DateTime(2026),
      simplifyDebts: simplify,
    );

void main() {
  group('Groups list', () {
    final friends = [
      _friend('Test Four', [_in('g1', 200)]),
      _friend('Test Receiver', [_in('g1', -50), _in('g2', 30)]),
      _friend('Asha Rao', [_in('g1', 10)]),
      _friend('Zero Person', [_in('g1', 0)]),
    ];
    final byGroup = groupPersonBalancesFrom(friends);

    test('per-person lines from the friends ledger, largest first', () {
      expect(groupBalanceLines(_group('g1', 160), byGroup['g1']!), [
        'Test F. owes you ₹200.00',
        'You owe Test R. ₹50.00',
        'Plus 1 more balance',
      ]);
    });

    test('no lines for simplified or settled groups', () {
      expect(
          groupBalanceLines(_group('g1', 160, simplify: true), byGroup['g1']!),
          isEmpty);
      expect(groupBalanceLines(_group('g3', 0), const []), isEmpty);
    });

    test('filters use the row balance', () {
      final groups = [_group('a', 10), _group('b', -5), _group('c', 0)];
      List<String> ids(GroupsListFilter f) =>
          filterGroups(groups, f).map((g) => g.id).toList();
      expect(ids(GroupsListFilter.all), ['a', 'b', 'c']);
      expect(ids(GroupsListFilter.outstanding), ['a', 'b']);
      expect(ids(GroupsListFilter.youOwe), ['b']);
      expect(ids(GroupsListFilter.oweYou), ['a']);
    });
  });

  group('Friends list', () {
    test('one line per open group, then "Plus N more groups"', () {
      final f = _friend('Test Receiver', [
        _in('g1', -50),
        _in('g2', 30),
        _in('g3', 0),
        _in('direct', 5, direct: true),
      ]);
      expect(friendBalanceLines(f), [
        'In Goa Trip: you owe Test R. ₹50.00',
        'In Flat: Test R. owes you ₹30.00',
        'Plus 1 more group',
      ]);
    });

    test('non-group balance', () {
      final f = _friend('Test', [_in('d', -10, direct: true)]);
      expect(friendBalanceLines(f), ['Non-group expenses: you owe ₹10.00']);
    });
  });

  testWidgets('rows fit a 320px phone with long names', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = _friend('A very long friend name that keeps going', [
      _in('g1', -123456.78),
      _in('g2', 30),
      _in('g3', 4),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            GroupRowCard(
              group: _group('A group with an extremely long name indeed', 99999),
              people: groupPersonBalancesFrom([f])['g1']!,
              onTap: () {},
            ),
            FriendListTile(friend: f, onTap: () {}),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('you are owed'), findsOneWidget);
    expect(find.text('Plus 1 more group'), findsOneWidget);
  });
}
