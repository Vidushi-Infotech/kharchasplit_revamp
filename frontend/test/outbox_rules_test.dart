import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/outbox/outbox_item.dart';
import 'package:kharchasplit/core/outbox/outbox_rules.dart';

OutboxItem item(String id, OutboxKind kind, {String? expenseId, Map<String, dynamic>? body, OutboxStatus status = OutboxStatus.pending}) =>
    OutboxItem(
      id: id,
      userId: 'u',
      kind: kind,
      method: switch (kind) {
        OutboxKind.updateExpense => 'PUT',
        OutboxKind.deleteExpense => 'DELETE',
        _ => 'POST',
      },
      path: expenseId == null ? '/expenses' : '/expenses/$expenseId',
      body: body,
      groupId: 'g',
      expenseId: expenseId,
      createdAt: DateTime(2026),
      status: status,
    );

void main() {
  test('which writes can wait offline', () {
    expect(OutboxRules.kindFor('POST', '/expenses'), OutboxKind.createExpense);
    expect(OutboxRules.kindFor('put', '/expenses/e1'), OutboxKind.updateExpense);
    expect(OutboxRules.kindFor('DELETE', '/expenses/e1'), OutboxKind.deleteExpense);
    expect(OutboxRules.kindFor('POST', '/settlements'), OutboxKind.createSettlement);
    expect(OutboxRules.kindFor('POST', '/settlements/settle-all'), isNull);
    expect(OutboxRules.kindFor('POST', '/expenses/e1/comments'), isNull);
    expect(OutboxRules.kindFor('POST', '/groups'), isNull);
  });

  test('editing / deleting an expense created offline never reaches the server', () {
    final create = item('c1', OutboxKind.createExpense, body: {'description': 'Tea', 'amount': 50});
    var q = OutboxRules.enqueue([create], item('x', OutboxKind.updateExpense, expenseId: 'local-c1', body: {'amount': 60, 'baseUpdatedAt': 't'}));
    expect(q, hasLength(1));
    expect(q.single.body, {'description': 'Tea', 'amount': 60});
    q = OutboxRules.enqueue(q, item('y', OutboxKind.deleteExpense, expenseId: 'local-c1'));
    expect(q, isEmpty);
  });

  test('second edit replaces the first and keeps its base version; delete drops edits', () {
    final first = item('a', OutboxKind.updateExpense, expenseId: 'e1', body: {'amount': 1, 'baseUpdatedAt': 'v1'});
    var q = OutboxRules.enqueue([first], item('b', OutboxKind.updateExpense, expenseId: 'e1', body: {'amount': 2, 'baseUpdatedAt': 'v1-cached'}));
    expect(q.single.body, {'amount': 2, 'baseUpdatedAt': 'v1'});
    q = OutboxRules.enqueue(q, item('c', OutboxKind.deleteExpense, expenseId: 'e1'));
    expect(q.map((i) => i.kind), [OutboxKind.deleteExpense]);
  });

  test('send results', () {
    final create = item('c', OutboxKind.createExpense);
    expect(OutboxRules.classify(item: create, connectivityError: true).isRetry, isTrue);
    expect(OutboxRules.classify(item: create, status: 503).isRetry, isTrue);
    expect(OutboxRules.classify(item: create, status: 201).isDone, isTrue);
    final f = OutboxRules.classify(item: create, status: 403, body: {'error': 'User is not a member of this group'});
    expect(f.isFailed, isTrue);
    expect(f.message, 'User is not a member of this group');
    final del = item('d', OutboxKind.deleteExpense, expenseId: 'e1');
    expect(OutboxRules.classify(item: del, status: 410, body: {'code': 'EXPENSE_DELETED'}).isDone, isTrue);
    final edit = item('u', OutboxKind.updateExpense, expenseId: 'e1', body: {'description': 'Tea', 'amount': 60});
    expect(OutboxRules.classify(item: edit, status: 409, body: {'code': 'EDIT_CONFLICT', 'current': {'description': 'Tea', 'amount': '60.00'}}).isDone, isTrue,
        reason: 'our own earlier attempt landed');
    expect(OutboxRules.classify(item: edit, status: 409, body: {'code': 'EDIT_CONFLICT', 'current': {'description': 'Coffee', 'amount': '80.00'}}).code, 'EDIT_CONFLICT');
  });

  test('items survive a JSON round trip; queued create looks like the API', () {
    final i = item('c', OutboxKind.createExpense, body: {
      'groupId': 'g', 'description': 'Tea', 'amount': 50, 'paidById': 'u',
      'participants': [{'userId': 'u', 'amount': 25}, {'userId': 'v', 'amount': 25}],
    }, status: OutboxStatus.failed);
    final back = OutboxItem.fromJson(i.toJson());
    expect(back.toJson(), i.toJson());
    final json = OutboxRules.expenseJson(i, at: '2026-01-01');
    expect(json['id'], 'local-c');
    expect(json['payers'], [{'user_id': 'u', 'amount': 50}]);
    expect((json['participants'] as List).length, 2);
  });
}
