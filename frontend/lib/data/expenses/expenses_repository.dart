import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/expense_model.dart';

class ExpensesApiException implements Exception {
  ExpensesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

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
      queryParameters: {
        'groupId': groupId,
        'page': page,
        'limit': limit,
      },
    );
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! List) {
      throw ExpensesApiException('Malformed response — expected list in data');
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
  }) async {
    final res = await _client.dio.post(
      '/expenses',
      data: {
        'groupId': groupId,
        'description': description,
        'amount': amount,
        'currency': _normalizeCurrency(currency),
        if (category != null) 'category': category,
        'paidById': paidById,
        'paidByName': paidByName,
        'splitType': splitType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (expenseDate != null)
          'expenseDate': expenseDate.toIso8601String(),
        if (receiptBase64 != null) 'receiptBase64': receiptBase64,
        'participants': participants.map((p) => p.toJson()).toList(),
      },
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
  }) async {
    final res = await _client.dio.put(
      '/expenses/$expenseId',
      data: {
        if (description != null) 'description': description,
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': _normalizeCurrency(currency),
        if (category != null) 'category': category,
        if (notes != null) 'notes': notes,
        if (expenseDate != null) 'expenseDate': expenseDate.toIso8601String(),
        if (receiptBase64 != null) 'receiptBase64': receiptBase64,
        if (paidById != null) 'paidById': paidById,
        if (splitType != null) 'splitType': splitType,
        if (participants != null)
          'participants': participants.map((p) => p.toJson()).toList(),
      },
    );
    final data = _ensureMap(res);
    return ExpenseModel.fromJson(data);
  }

  Future<void> delete(String expenseId) async {
    final res = await _client.dio.delete('/expenses/$expenseId');
    _ensureSuccess(res);
  }

  /// Backend stores currency as a 3-letter code (e.g. INR). The Flutter
  /// state often holds the symbol — normalise back to a code so the DB
  /// constraint passes.
  String _normalizeCurrency(String input) {
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

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw ExpensesApiException(msg, statusCode: res.statusCode);
    }
    return body.cast<String, dynamic>();
  }

  Map<String, dynamic> _ensureMap(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ExpensesApiException('Malformed response — expected object in data');
    }
    return data;
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(apiClientProvider));
});
