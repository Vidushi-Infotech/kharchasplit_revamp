import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/expense_model.dart';
import 'expenses_repository.dart';

/// One comment on an expense (GET /expenses/:id/comments).
class ExpenseComment {
  const ExpenseComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.canDelete = false,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String userId;

  /// "Former member" from the server when the author's account is gone.
  final String userName;
  final String? userAvatar;

  /// Only the author may delete a comment.
  final bool canDelete;

  factory ExpenseComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final created = json['createdAt'];
    return ExpenseComment(
      id: json['id'] as String,
      body: (json['body'] as String?) ?? '',
      createdAt: (created is String ? DateTime.tryParse(created) : null)
              ?.toLocal() ??
          DateTime.now(),
      userId: (user['id'] as String?) ?? '',
      userName: (user['name'] as String?) ?? 'Former member',
      userAvatar: user['profileImageBase64'] as String?,
      canDelete: json['canDelete'] == true,
    );
  }
}

/// The expense as it was BEFORE one edit (`expense_revisions.snapshot`).
class ExpenseSnapshot {
  const ExpenseSnapshot({
    required this.description,
    required this.amount,
    required this.currency,
    required this.category,
    required this.splitType,
    required this.isAdjustment,
    required this.notes,
    required this.payers,
    required this.participants,
  });

  final String description;
  final double amount;
  final String currency;
  final String category;
  final String splitType;
  final bool isAdjustment;
  final String notes;

  /// userId → amount paid / owed.
  final Map<String, double> payers;
  final Map<String, double> participants;

  static double _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static Map<String, double> _rows(Object? raw) => {
        if (raw is List)
          for (final r in raw.whereType<Map<String, dynamic>>())
            (r['user_id'] ?? '') as String: _num(r['amount']),
      };

  factory ExpenseSnapshot.fromJson(Map<String, dynamic> json) {
    final amount = _num(json['amount']);
    final payers = _rows(json['payers']);
    final paidBy = json['paid_by'] as String?;
    final meta = json['split_meta'];
    return ExpenseSnapshot(
      description: (json['description'] as String?) ?? '',
      amount: amount,
      currency: (json['currency'] as String?) ?? 'INR',
      category: (json['category'] as String?) ?? 'other',
      splitType: (json['split_type'] as String?) ?? 'equal',
      isAdjustment: meta is Map && meta['mode'] == 'adjustment',
      notes: (json['notes'] as String?) ?? '',
      // Revisions taken before multi-payer existed only carry paid_by.
      payers: payers.isEmpty && paidBy != null ? {paidBy: amount} : payers,
      participants: _rows(json['participants']),
    );
  }

  /// The live expense in the same shape, so the newest revision can be
  /// compared with what the expense looks like now.
  factory ExpenseSnapshot.fromExpense(ExpenseModel e) => ExpenseSnapshot(
        description: e.title,
        amount: e.amount,
        currency: e.currency,
        category: e.category.id,
        splitType: switch (e.splitType) {
          SplitType.equal => 'equal',
          SplitType.exact => 'exact',
          SplitType.percentage => 'percentage',
          SplitType.shares => 'shares',
        },
        isAdjustment: e.isAdjustmentSplit,
        notes: e.notes ?? '',
        payers: {for (final p in e.payers) p.userId: p.amount},
        participants: {for (final s in e.splits) s.userId: s.owedShare},
      );
}

/// One entry of GET /expenses/:id/history.
class ExpenseRevision {
  const ExpenseRevision({
    required this.id,
    required this.createdAt,
    required this.snapshot,
    this.editorId,
    this.editorName,
  });

  final String id;
  final DateTime createdAt;
  final ExpenseSnapshot snapshot;
  final String? editorId;
  final String? editorName;

  factory ExpenseRevision.fromJson(Map<String, dynamic> json) {
    final editor = json['editedBy'];
    final created = json['createdAt'];
    return ExpenseRevision(
      id: json['id'] as String,
      createdAt: (created is String ? DateTime.tryParse(created) : null)
              ?.toLocal() ??
          DateTime.now(),
      snapshot: ExpenseSnapshot.fromJson(
        json['snapshot'] is Map<String, dynamic>
            ? json['snapshot'] as Map<String, dynamic>
            : const {},
      ),
      editorId: editor is Map ? editor['id'] as String? : null,
      editorName: editor is Map ? editor['name'] as String? : null,
    );
  }
}

/// Revisions newest first, plus a name for everyone they mention
/// (including people who have left the group).
class ExpenseHistory {
  const ExpenseHistory({required this.revisions, required this.userNames});
  final List<ExpenseRevision> revisions;
  final Map<String, String> userNames;
}

/// Comments and edit history on an expense. Errors are
/// [ExpensesApiException]s (status + server `code`, e.g. `MEMBER_LEFT`).
class ExpenseExtrasRepository {
  ExpenseExtrasRepository(this._client);
  final ApiClient _client;

  Future<List<ExpenseComment>> listComments(String expenseId) async {
    final data = _data(await _client.dio.get('/expenses/$expenseId/comments'));
    if (data is! List) throw ExpensesApiException('Malformed comments');
    return data
        .whereType<Map<String, dynamic>>()
        .map(ExpenseComment.fromJson)
        .toList();
  }

  Future<ExpenseComment> addComment(String expenseId, String body) async {
    final data = _data(await _client.dio.post(
      '/expenses/$expenseId/comments',
      data: {'body': body},
    ));
    if (data is! Map<String, dynamic>) {
      throw ExpensesApiException('Malformed comment');
    }
    return ExpenseComment.fromJson(data);
  }

  Future<void> deleteComment(String expenseId, String commentId) async {
    _data(await _client.dio.delete('/expenses/$expenseId/comments/$commentId'));
  }

  Future<ExpenseHistory> history(String expenseId) async {
    final data = _data(await _client.dio.get('/expenses/$expenseId/history'));
    if (data is! Map<String, dynamic>) {
      throw ExpensesApiException('Malformed history');
    }
    final users = data['users'];
    return ExpenseHistory(
      revisions: ((data['revisions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExpenseRevision.fromJson)
          .toList(),
      userNames: {
        if (users is Map)
          for (final e in users.entries) '${e.key}': '${e.value}',
      },
    );
  }

  /// Puts that version back. 403 for non-payers, 409 `MEMBER_LEFT` /
  /// `GROUP_ARCHIVED`.
  Future<void> restore(String expenseId, String revisionId) async {
    _data(await _client.dio.post(
      '/expenses/$expenseId/history/$revisionId/restore',
    ));
  }

  /// `data` of a `{success: true}` envelope, else throws with the
  /// server's message and code.
  Object? _data(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      throw ExpensesApiException(
        (body is Map ? body['error'] : null)?.toString() ??
            'Request failed (status ${res.statusCode})',
        statusCode: res.statusCode,
        code: body is Map ? body['code'] as String? : null,
      );
    }
    return body['data'];
  }
}

final expenseExtrasRepositoryProvider = Provider<ExpenseExtrasRepository>(
  (ref) => ExpenseExtrasRepository(ref.watch(apiClientProvider)),
);
