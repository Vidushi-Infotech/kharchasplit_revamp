import 'dart:convert';

import 'outbox_item.dart';

/// Pure rules of the offline outbox (no Dio / Hive), unit-tested.
abstract final class OutboxRules {
  static final _expenseById = RegExp(r'^/expenses/([^/]+)$');

  /// A queued body bigger than this drops its receipt photo.
  static const maxBodyChars = 3 * 1024 * 1024;

  /// Which writes may wait in the outbox. Everything else (settle-all,
  /// groups, comments, …) needs the server's answer and stays online-only.
  static OutboxKind? kindFor(String method, String path) {
    final m = method.toUpperCase();
    if (m == 'POST' && path == '/expenses') return OutboxKind.createExpense;
    if (m == 'POST' && path == '/settlements') return OutboxKind.createSettlement;
    final id = _expenseById.firstMatch(path)?.group(1);
    if (id == null || id == 'category-suggestion') return null;
    if (m == 'PUT') return OutboxKind.updateExpense;
    if (m == 'DELETE') return OutboxKind.deleteExpense;
    return null;
  }

  /// The expense id in `/expenses/:id`.
  static String? expenseIdOf(String path) => _expenseById.firstMatch(path)?.group(1);

  static bool isLocalId(String? id) => id != null && id.startsWith('local-');
  static String itemIdOfLocal(String localId) => localId.substring('local-'.length);

  /// Body to keep: unchanged, or without the receipt if too big.
  static ({Map<String, dynamic>? body, bool receiptDropped}) trimBody(Map<String, dynamic>? body) {
    if (body == null || jsonEncode(body).length <= maxBodyChars) {
      return (body: body, receiptDropped: false);
    }
    return (body: Map.of(body)..remove('receiptBase64'), receiptDropped: true);
  }

  /// The queue after adding [incoming], merging with what's already there:
  /// * editing an expense created offline rewrites that create;
  /// * deleting it removes the create (nothing ever reaches the server);
  /// * a second edit of the same expense replaces the first (keeping the
  ///   first one's baseUpdatedAt — the version it was all made against);
  /// * deleting an expense drops its queued edits.
  static List<OutboxItem> enqueue(List<OutboxItem> items, OutboxItem incoming) {
    final target = incoming.expenseId;
    if (isLocalId(target)) {
      final createId = itemIdOfLocal(target!);
      if (incoming.kind == OutboxKind.deleteExpense) {
        return items.where((i) => i.id != createId).toList();
      }
      if (incoming.kind == OutboxKind.updateExpense) {
        return [
          for (final i in items)
            if (i.id == createId)
              i.copyWith(
                body: {...?i.body, ...?incoming.body}..remove('baseUpdatedAt'),
                status: OutboxStatus.pending,
                clearError: true,
              )
            else
              i,
        ];
      }
    }
    if (incoming.kind == OutboxKind.updateExpense && target != null) {
      final prev = items.where((i) =>
          i.kind == OutboxKind.updateExpense && i.expenseId == target && !i.isFailed);
      if (prev.isNotEmpty) {
        final base = prev.first.body?['baseUpdatedAt'];
        return [
          for (final i in items)
            if (identical(i, prev.first))
              i.copyWith(body: {...?incoming.body, 'baseUpdatedAt': ?base})
            else
              i,
        ];
      }
    }
    if (incoming.kind == OutboxKind.deleteExpense && target != null) {
      return [
        ...items.where((i) => !(i.kind == OutboxKind.updateExpense && i.expenseId == target)),
        incoming,
      ];
    }
    return [...items, incoming];
  }

  /// What the app is told right away for a queued write (as if the server
  /// had answered), so screens close as on success.
  static Map<String, dynamic> syntheticResponse(OutboxItem item, {DateTime? now}) {
    final at = (now ?? DateTime.now()).toIso8601String();
    final b = item.body ?? const {};
    switch (item.kind) {
      case OutboxKind.createExpense:
        return {'success': true, 'queued': true, 'data': expenseJson(item, at: at)};
      case OutboxKind.updateExpense:
        return {
          'success': true,
          'queued': true,
          'data': {
            'id': item.expenseId,
            'group_id': item.groupId,
            'description': b['description'],
            'amount': b['amount'],
            'updated_at': at,
          },
        };
      case OutboxKind.deleteExpense:
        return {'success': true, 'queued': true};
      case OutboxKind.createSettlement:
        return {
          'success': true,
          'queued': true,
          'data': {
            'id': item.localId,
            'group_id': b['groupId'],
            'from_user_id': b['fromUserId'],
            'to_user_id': b['toUserId'],
            'amount': b['amount'],
            'currency': b['currency'],
            'status': 'paid',
            'method': b['method'],
            'notes': b['notes'],
            'created_at': at,
            'settled_at': at,
          },
        };
    }
  }

  /// A queued create as the API's expense JSON (for showing it offline).
  static Map<String, dynamic> expenseJson(OutboxItem item, {required String at}) {
    final b = item.body ?? const {};
    final participants = (b['participants'] as List?) ?? const [];
    final payers = (b['payers'] as List?) ??
        [
          {'userId': b['paidById'], 'amount': b['amount']},
        ];
    return {
      'id': item.localId,
      'group_id': b['groupId'] ?? item.groupId,
      'description': b['description'],
      'amount': b['amount'],
      'currency': b['currency'],
      'category': b['category'],
      'paid_by': b['paidById'],
      'paid_by_name': b['paidByName'],
      'split_type': b['splitType'],
      'split_meta': b['splitMeta'],
      'notes': b['notes'],
      'expense_date': b['expenseDate'] ?? at,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': at,
      'participants': [
        for (final p in participants.whereType<Map>())
          {
            'user_id': p['userId'],
            'amount': p['amount'],
            'percentage': p['percentage'],
            'shares': p['shares'],
          },
      ],
      'payers': [
        for (final p in payers.whereType<Map>())
          {'user_id': p['userId'], 'amount': p['amount']},
      ],
    };
  }

  /// How a send attempt ended.
  static SendOutcome classify({
    required OutboxItem item,
    int? status,
    Object? body,
    bool connectivityError = false,
  }) {
    if (connectivityError || status == null || status >= 500) {
      return const SendOutcome.retryLater();
    }
    if (status >= 200 && status < 300) return const SendOutcome.done();
    final map = body is Map ? body : const {};
    final code = map['code'] as String?;
    // Deleting something already deleted is what we wanted.
    if (item.kind == OutboxKind.deleteExpense && (status == 410 || status == 404)) {
      return const SendOutcome.done();
    }
    // A replay of an edit that did reach the server the first time (its
    // response was lost) looks like a conflict with itself.
    if (code == 'EDIT_CONFLICT' && _sameEdit(item.body, map['current'])) {
      return const SendOutcome.done();
    }
    return SendOutcome.failed(code: code, message: map['error']?.toString());
  }

  static bool _sameEdit(Map<String, dynamic>? body, Object? current) {
    if (body == null || current is! Map) return false;
    final amount = double.tryParse('${current['amount']}');
    return body['description'] == current['description'] &&
        (body['amount'] == null || (amount != null && (amount - (body['amount'] as num)).abs() < 0.005));
  }
}

class SendOutcome {
  const SendOutcome.done() : kind = 'done', code = null, message = null;
  const SendOutcome.retryLater() : kind = 'retry', code = null, message = null;
  const SendOutcome.failed({this.code, this.message}) : kind = 'failed';

  final String kind;
  final String? code;
  final String? message;

  bool get isDone => kind == 'done';
  bool get isRetry => kind == 'retry';
  bool get isFailed => kind == 'failed';
}
