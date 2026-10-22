import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/activity_model.dart';
import 'package:kharchasplit/modules/activity/state/activity_sentence.dart';
import 'package:kharchasplit/modules/activity/widgets/activity_row.dart';

const _me = 'u-me';

/// A feed row as GET /activities returns it.
ActivityModel _row(
  String type,
  Map<String, dynamic> metadata, {
  String actorId = _me,
  String actorName = 'Test Payer',
  String entityType = 'expense',
}) =>
    ActivityModel.fromJson({
      'id': 'a1',
      'userId': actorId,
      'groupId': 'g1',
      'activityType': type,
      'entityType': entityType,
      'entityId': 'e1',
      'title': 'Expense added',
      'description': 'server text',
      'metadata': metadata,
      'isRead': false,
      'createdAt': '2026-10-21T11:34:39.320Z',
      'actorName': actorName,
      'groupName': 'Settle Flow Test',
    });

extension on ActivityModel {
  /// The fields [_row] feeds through fromJson, so a test can add more.
  Map<String, dynamic> toJsonForTest() => {
        'id': id,
        'userId': actorId,
        'groupId': 'g1',
        'activityType': 'expense_added',
        'entityType': entityType,
        'entityId': entityId,
        'title': 'Expense added',
        'description': description,
        'metadata': metadata,
        'isRead': isRead,
        'createdAt': timestamp.toIso8601String(),
        'actorName': actorUser?.name,
        'groupName': 'Settle Flow Test',
      };
}

ActivitySentence _build(ActivityModel a) =>
    buildActivitySentence(a, myUserId: _me, myName: 'Test Payer');

void main() {
  group('your side of an expense (yourNet)', () {
    const meta = {
      'amount': 1000,
      'currency': 'INR',
      'groupName': 'Settle Flow Test',
      'expenseDescription': 'Dinner',
    };
    ActivitySentence withNet(double? net) => _build(
          ActivityModel.fromJson({
            ..._row('expense_added', meta, actorId: 'u-other',
                    actorName: 'Test Receiver')
                .toJsonForTest(),
            'yourNet': net,
          }),
        );

    test('another member added it and you owe', () {
      final s = withNet(-500);
      expect(s.text, 'Test Receiver added "Dinner" in "Settle Flow Test".');
      expect(s.amountLine, 'You owe ₹500.00');
      expect(s.amountTone, ActivityAmountTone.paid);
    });

    test('you get back', () {
      final s = withNet(200);
      expect(s.amountLine, 'You get back ₹200.00');
      expect(s.amountTone, ActivityAmountTone.received);
    });

    test('even, and not involved falls back to the total', () {
      expect(withNet(0).amountLine, 'You do not owe anything');
      expect(withNet(null).amountLine, 'Total ₹1,000.00');
    });
  });

  group('buildActivitySentence', () {
    test('expense added: who, what, where, with the total', () {
      final s = _build(_row('expense_added', {
        'amount': 2585,
        'currency': 'INR',
        'groupName': 'Settle Flow Test',
        'expenseDescription': 'Dinner',
      }));
      expect(s.text, 'You added "Dinner" in "Settle Flow Test".');
      expect(s.spans.where((p) => p.bold).map((p) => p.text.trim()),
          ['You', '"Dinner"', '"Settle Flow Test"']);
      expect(s.amountLine, 'Total ₹2,585.00');
      expect(s.amountTone, ActivityAmountTone.neutral);
    });

    test("someone else's edit uses their name; NUMERIC strings parse", () {
      final s = _build(_row(
        'expense_updated',
        {'amount': '1000.00', 'currency': 'INR', 'expenseDescription': 'Cab'},
        actorId: 'u-2',
        actorName: 'Test Receiver',
      ));
      expect(s.text, 'Test Receiver updated "Cab" in "Settle Flow Test".');
      expect(s.amountLine, 'Total ₹1,000.00');
    });

    test('deleted expense has no amount line and does not open', () {
      final a = _row('expense_deleted', {'expenseDescription': 'Snacks'});
      expect(_build(a).text, 'You deleted "Snacks" from "Settle Flow Test".');
      expect(_build(a).amountLine, isNull);
      expect(activityRoute(a), '/home/groups/g1');
    });

    test('payment you made', () {
      final s = _build(_row(
        'settlement_created',
        {
          'amount': 350,
          'currency': 'INR',
          'fromName': 'Test Payer',
          'toName': 'Test Receiver',
          'groupName': 'P2 G1',
        },
        entityType: 'settlement',
      ));
      expect(s.text, 'You paid Test Receiver in "P2 G1".');
      expect(s.amountLine, 'You paid ₹350.00');
      expect(s.amountTone, ActivityAmountTone.paid);
    });

    test('group and member events', () {
      expect(
        _build(_row('group_created', {'groupName': 'Goa'},
                entityType: 'group'))
            .text,
        'You created the group "Goa".',
      );
      expect(
        _build(_row('member_added', {'memberName': 'Test Receiver'},
                entityType: 'member'))
            .text,
        'You added Test Receiver to "Settle Flow Test".',
      );
      expect(
        _build(_row('group_updated', {
          'changes': {'simplifyDebts': true},
        }, entityType: 'group'))
            .text,
        'You turned on simplify debts in "Settle Flow Test".',
      );
    });

    test('unknown events fall back to the server description', () {
      final s = _build(_row('something_new', const {}));
      expect(s.text, 'server text');
      expect(ActivityModel.fromJson({
        'id': 'x',
        'activityType': 'something_new',
        'createdAt': '2026-10-21T11:34:39.320Z',
      }).type, ActivityType.other);
    });
  });

  group('activityRoute', () {
    test('expense rows open the expense', () {
      expect(activityRoute(_row('expense_added', const {})), '/expense/e1');
    });
  });

  group('activityTimeLabel', () {
    final now = DateTime(2026, 10, 22, 12);
    test('today / yesterday / this year / older', () {
      expect(activityTimeLabel(DateTime(2026, 10, 22, 18, 30), now: now),
          'Today, 6:30 PM');
      expect(activityTimeLabel(DateTime(2026, 10, 21, 9, 5), now: now),
          'Yesterday, 9:05 AM');
      expect(activityTimeLabel(DateTime(2026, 3, 4, 9, 5), now: now),
          'Mar 4, 9:05 AM');
      expect(activityTimeLabel(DateTime(2025, 3, 4, 9, 5), now: now),
          'Mar 4, 2025, 9:05 AM');
    });
  });

  testWidgets('ActivityRow shows the sentence, total and unread dot',
      (tester) async {
    final a = _row('expense_added', {
      'amount': 500,
      'currency': 'INR',
      'expenseDescription': 'Dinner',
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActivityRow(
          activity: a,
          sentence: _build(a),
          badgeName: 'Test Payer',
          onTap: () {},
        ),
      ),
    ));
    expect(find.textContaining('added', findRichText: true), findsOneWidget);
    expect(find.text('Total ₹500.00'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Unread\. You added "Dinner"')),
      findsOneWidget,
    );
  });
}
