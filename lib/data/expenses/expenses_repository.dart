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

  Future<List<ExpenseModel>> listForGroup(
    String groupId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.dio.get(
      '/expenses',
      queryParameters: {
        'groupId': groupId,
        'page': page,
        'limit': limit,
      },
    );
    final data = _ensureList(res);
    return data
        .whereType<Map<String, dynamic>>()
        .map(ExpenseModel.fromJson)
        .toList();
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

  List<dynamic> _ensureList(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! List) {
      throw ExpensesApiException('Malformed response — expected list in data');
    }
    return data;
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(apiClientProvider));
});
