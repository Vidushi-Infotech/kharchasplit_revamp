import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/data/recurring/recurring_repository.dart';
import 'package:kharchasplit/models/group_model.dart';
import 'package:kharchasplit/modules/expenses/state/recurring_rule_text.dart';

RecurringRule _rule({
  String frequency = 'monthly',
  String nextDate = '2026-12-31',
  String? endDate,
  bool paused = false,
  String? pauseReason,
  String? createdBy = 'creator',
  List<Map<String, dynamic>> payers = const [],
}) => RecurringRule.fromJson({
  'id': 'r1',
  'groupId': 'g1',
  'createdBy': createdBy,
  'template': {'description': 'Rent', 'amount': '1000.00', 'payers': payers},
  'frequency': frequency,
  'anchorDate': '2026-10-31',
  'nextDate': nextDate,
  'endDate': endDate,
  'paused': paused,
  'pauseReason': pauseReason,
});

void main() {
  final now = DateTime(2026, 10, 21);

  group('recurringSummary', () {
    test('active monthly rule', () {
      expect(
        recurringSummary(_rule(), now: now),
        'Repeats every month · Next on 31 Dec',
      );
    });

    test('other year shows the year, end date appended', () {
      expect(
        recurringSummary(
          _rule(
            frequency: 'biweekly',
            nextDate: '2027-01-14',
            endDate: '2027-06-30',
          ),
          now: now,
        ),
        'Repeats every 2 weeks · Next on 14 Jan 2027 · Ends 30 Jun 2027',
      );
    });

    test('paused rule shows why instead of the next date', () {
      expect(
        recurringSummary(
          _rule(
            frequency: 'weekly',
            paused: true,
            pauseReason: 'someone in it has left the group',
          ),
          now: now,
        ),
        'Repeats every week · Paused: someone in it has left the group',
      );
    });
  });

  group('recurringPauseLabel', () {
    test('by hand', () {
      expect(recurringPauseLabel('paused'), 'Paused');
      expect(recurringPauseLabel(null), 'Paused');
      expect(recurringPauseLabel('  '), 'Paused');
    });
    test('ended', () => expect(recurringPauseLabel('ended'), 'Ended'));
    test('server reason', () {
      expect(
        recurringPauseLabel('the group was archived'),
        'Paused: the group was archived',
      );
    });
  });

  test('recurringShortDate keeps unparseable input', () {
    expect(recurringShortDate('nope', now: now), 'nope');
    expect(recurringShortDate('2026-03-05', now: now), '5 Mar');
  });

  test('recurringPayerIds reads template payers', () {
    final rule = _rule(
      payers: [
        {'userId': 'a', 'amount': '500'},
        {'userId': 'b', 'amount': '500'},
      ],
    );
    expect(recurringPayerIds(rule), ['a', 'b']);
    expect(recurringPayerIds(_rule()), isEmpty);
  });

  group('canManageRecurringRule', () {
    GroupModel group({String? createdBy, String kind = 'group'}) =>
        GroupModel.fromJson({
          'id': 'g1',
          'name': 'Flat',
          'createdBy': createdBy,
          'kind': kind,
        });

    test('creator can', () {
      expect(
        canManageRecurringRule(rule: _rule(), myId: 'creator', group: null),
        isTrue,
      );
    });
    test('group admin can, plain member cannot', () {
      final g = group(createdBy: 'admin');
      expect(
        canManageRecurringRule(rule: _rule(), myId: 'admin', group: g),
        isTrue,
      );
      expect(
        canManageRecurringRule(rule: _rule(), myId: 'member', group: g),
        isFalse,
      );
    });
    test('a direct group has no admin', () {
      final g = group(createdBy: 'other', kind: 'direct');
      expect(
        canManageRecurringRule(rule: _rule(), myId: 'other', group: g),
        isFalse,
      );
    });
    test('signed out cannot', () {
      expect(
        canManageRecurringRule(rule: _rule(), myId: null, group: null),
        isFalse,
      );
    });
  });
}
