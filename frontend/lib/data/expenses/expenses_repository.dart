import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/expense_model.dart';

class ExpensesApiException implements Exception {
  ExpensesApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;

  /// Machine-readable error tag from the server, e.g. `GROUP_ARCHIVED`
  /// (409 when creating / editing / deleting in an archived group).
  final String? code;

  bool get isGroupArchived => code == 'GROUP_ARCHIVED';

  /// 400: what the payers paid doesn't add up to the amount (to the paisa).
  bool get isPayersMismatch => code == 'PAYERS_MISMATCH';

  /// 400: what the participants owe doesn't add up to the amount.
  bool get isSplitMismatch => code == 'SPLIT_MISMATCH';

  /// 409: editing a multi-payer expense needs a newer app (one that sends
  /// `payers`).
  bool get needsAppUpdate => code == 'UPDATE_APP';

  /// 409: someone changed the expense since this edit's version.
  bool get isEditConflict => code == 'EDIT_CONFLICT';

  /// 410: the expense was deleted.
  bool get isDeleted => code == 'EXPENSE_DELETED';

  /// 503: no exchange rate for an expense entered in another currency
  /// (currency not covered / rate service down). Retry with `fxRate`.
  bool get isFxUnavailable => code == 'FX_UNAVAILABLE';

  /// 400: the receipt isn't a JPEG / PNG / WebP / HEIC / PDF or is over
  /// 8 MB.
  bool get isInvalidReceipt => code == 'INVALID_RECEIPT';

  @override
  String toString() => message;
}

/// Single participant share for the POST body. Matches the backend's
/// `participants` array on `/expenses`.
class ExpenseParticipant {
  ExpenseParticipant({
    required this.userId,
    required this.name,
    required this.amount,
    this.percentage,
    this.shares,
  });

  final String userId;
  final String name;
  final double amount;
  final double? percentage;
  final int? shares;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'amount': amount,
    if (percentage != null) 'percentage': percentage,
    if (shares != null) 'shares': shares,
  };
}

/// Request body for `payers` (userId → paise) — paise so the amounts sent
/// are exactly what the client checked against the total. Also the
/// `payers` of a recurring rule's template.
List<Map<String, dynamic>> expensePayersJson(Map<String, int> payersPaise) => [
  for (final e in payersPaise.entries)
    {'userId': e.key, 'amount': e.value / 100},
];

/// Backend stores currency as a 3-letter code (e.g. INR). The Flutter
/// state often holds the symbol — normalise back to a code so the DB
/// constraint passes.
String normalizeCurrencyCode(String input) {
  switch (input) {
    case '₹':
      return 'INR';
    case '\$':
      return 'USD';
    case '€':
      return 'EUR';
    case '£':
      return 'GBP';
    default:
      return input.length == 3 ? input.toUpperCase() : 'INR';
  }
}

class ExpensesRepository {
  ExpensesRepository(this._client);
  final ApiClient _client;

  /// One page of expenses. Prefer [listAllForGroup] whenever the result
  /// feeds a balance calculation — a single page silently truncates the maths
  /// once a group crosses [limit] expenses.
  Future<List<ExpenseModel>> listForGroup(
    String groupId, {
    int page = 1,
    int limit = 50,
  }) async {
    final result = await _fetchPage(groupId, page: page, limit: limit);
    return result.items;
  }

  /// Every expense in the group, walking `pagination.hasMore` until the
  /// backend reports nothing left. Bounded by [_maxPages] as a safety net
  /// against a misbehaving server that always says `hasMore: true`.
  Future<List<ExpenseModel>> listAllForGroup(
    String groupId, {
    int pageSize = _defaultPageSize,
  }) async {
    final out = <ExpenseModel>[];
    for (var page = 1; page <= _maxPages; page++) {
      final result = await _fetchPage(groupId, page: page, limit: pageSize);
      out.addAll(result.items);
      if (!result.hasMore) break;
    }
    return out;
  }

  static const int _defaultPageSize = 100;
  static const int _maxPages = 50;

  Future<({List<ExpenseModel> items, bool hasMore})> _fetchPage(
    String groupId, {
    required int page,
    required int limit,
  }) async {
    final res = await _client.dio.get(
      '/expenses',
      queryParameters: {'groupId': groupId, 'page': page, 'limit': limit},
    );
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! List) {
      throw ExpensesApiException('Malformed response: expected list in data');
    }
    final items = data
        .whereType<Map<String, dynamic>>()
        .map(ExpenseModel.fromJson)
        .toList();
    return (items: items, hasMore: _readHasMore(body, items.length, limit));
  }

  /// Reads `pagination.hasMore` from the envelope. Falls back to "page was
  /// full" if the backend didn't send pagination metadata, so an older server
  /// still terminates the loop correctly.
  static bool _readHasMore(Map<String, dynamic> body, int received, int limit) {
    final pagination = body['pagination'];
    if (pagination is Map && pagination['hasMore'] is bool) {
      return pagination['hasMore'] as bool;
    }
    return received >= limit;
  }

  Future<ExpenseModel> getById(String expenseId) async {
    final res = await _client.dio.get('/expenses/$expenseId');
    final data = _ensureMap(res);
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> create({
    required String groupId,
    required String description,
    required double amount,
    required String currency,
    String? category,
    required String paidById,
    required String paidByName,
    required String splitType,
    String? notes,
    DateTime? expenseDate,
    String? receiptBase64,
    required List<ExpenseParticipant> participants,
    Map<String, int>? payersPaise,
    Map<String, dynamic>? splitMeta,
    Map<String, dynamic>? repeat,
    String? originalCurrency,
    double? fxRate,
  }) async {
    final res = await _sendWrite(
      () => _client.dio.post(
        '/expenses',
        options: _fxOptions(originalCurrency, fxRate),
        data: {
          'groupId': groupId,
          'description': description,
          'amount': amount,
          'currency': normalizeCurrencyCode(currency),
          if (category != null) 'category': category,
          'paidById': paidById,
          'paidByName': paidByName,
          'splitType': splitType,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (expenseDate != null) 'expenseDate': expenseDate.toIso8601String(),
          if (receiptBase64 != null) 'receiptBase64': receiptBase64,
          'participants': participants.map((p) => p.toJson()).toList(),
          if (payersPaise != null) 'payers': expensePayersJson(payersPaise),
          'splitMeta': ?splitMeta,
          // {frequency, endDate?}: this expense becomes the first occurrence
          // of a new recurring rule (same transaction on the server).
          'repeat': ?repeat,
          // Entered in another currency: amount / payers / participants are
          // in it and the server converts them (fxRate = the user's own rate
          // when none could be looked up).
          'originalCurrency': ?originalCurrency,
          'fxRate': ?fxRate,
        },
      ),
    );
    final data = _ensureMap(res);
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> update(
    String expenseId, {
    String? description,
    double? amount,
    String? currency,
    String? category,
    String? notes,
    DateTime? expenseDate,
    String? receiptBase64,
    String? paidById,
    String? splitType,
    List<ExpenseParticipant>? participants,
    Map<String, int>? payersPaise,
    Map<String, dynamic>? splitMeta,
    String? baseUpdatedAt,
    String? groupId,
    String? originalCurrency,
    double? fxRate,
  }) async {
    final res = await _sendWrite(
      () => _client.dio.put(
        '/expenses/$expenseId',
        options: _fxOptions(originalCurrency, fxRate),
        data: {
          // Not used by the server; lets an edit queued offline be shown in
          // its group straight away.
          'groupId': ?groupId,
          if (description != null) 'description': description,
          if (amount != null) 'amount': amount,
          if (currency != null) 'currency': normalizeCurrencyCode(currency),
          if (category != null) 'category': category,
          if (notes != null) 'notes': notes,
          if (expenseDate != null) 'expenseDate': expenseDate.toIso8601String(),
          if (receiptBase64 != null) 'receiptBase64': receiptBase64,
          if (paidById != null) 'paidById': paidById,
          if (splitType != null) 'splitType': splitType,
          if (participants != null)
            'participants': participants.map((p) => p.toJson()).toList(),
          if (payersPaise != null) 'payers': expensePayersJson(payersPaise),
          'splitMeta': ?splitMeta,
          // The version this edit was made against (409 EDIT_CONFLICT if the
          // expense changed since).
          'baseUpdatedAt': ?baseUpdatedAt,
          // Without these an edit that sends the amount drops the
          // original-currency record (see [create]).
          'originalCurrency': ?originalCurrency,
          'fxRate': ?fxRate,
        },
      ),
    );
    final data = _ensureMap(res);
    return ExpenseModel.fromJson(data);
  }

  /// The category the user last used for the same description, or null.
  /// Best effort: any failure is just "no suggestion".
  Future<String?> suggestCategory(String description) async {
    try {
      final res = await _client.dio.get(
        '/expenses/category-suggestion',
        queryParameters: {'description': description},
      );
      final data = _ensureSuccess(res)['data'];
      return data is Map ? data['category'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  /// [groupId] only helps an offline-queued delete hide the expense in its
  /// group right away; the server ignores it.
  Future<void> delete(String expenseId, {String? groupId}) async {
    final res = await _client.dio.delete(
      '/expenses/$expenseId',
      queryParameters: {'groupId': ?groupId},
    );
    _ensureSuccess(res);
  }

  /// A save that makes the server look up an exchange rate isn't retried:
  /// 503 FX_UNAVAILABLE won't pass in seconds, and the form offers "Enter
  /// rate" instead.
  static Options? _fxOptions(String? originalCurrency, double? fxRate) =>
      originalCurrency != null && fxRate == null
      ? Options(extra: {'noRetry': true})
      : null;

  /// A create / edit. 5xx arrive as [DioException]s (see ApiClient); one
  /// with the server's `{code, error}` body — 503 FX_UNAVAILABLE — becomes
  /// an [ExpensesApiException] like the 4xx ones.
  Future<Response> _sendWrite(Future<Response> Function() send) async {
    try {
      return await send();
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['code'] is String) {
        throw ExpensesApiException(
          body['error']?.toString() ?? 'Request failed',
          statusCode: e.response?.statusCode,
          code: body['code'] as String,
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg =
          (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw ExpensesApiException(
        msg,
        statusCode: res.statusCode,
        code: body is Map ? body['code'] as String? : null,
      );
    }
    return body.cast<String, dynamic>();
  }

  Map<String, dynamic> _ensureMap(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ExpensesApiException(
        'Malformed response: expected object in data',
      );
    }
    return data;
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(apiClientProvider));
});
