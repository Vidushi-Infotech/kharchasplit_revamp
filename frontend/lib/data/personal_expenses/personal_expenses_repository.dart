import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/personal_expense_model.dart';
import '../../models/personal_summary_model.dart';

class PersonalExpensesApiException implements Exception {
  PersonalExpensesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PersonalExpensesRepository {
  PersonalExpensesRepository(this._client);
  final ApiClient _client;

  Future<List<PersonalExpenseModel>> listForUser(
    String userId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.dio.get(
      '/personal-expenses',
      queryParameters: {
        'userId': userId,
        'page': page,
        'limit': limit,
        // Without it the server leaves income out (for older apps).
        'includeIncome': '1',
      },
    );
    final data = _ensureList(res);
    return data
        .whereType<Map<String, dynamic>>()
        .map(PersonalExpenseModel.fromJson)
        .toList();
  }

  /// Insights for [month] (any day in it), with days split at the phone's
  /// midnight.
  Future<PersonalSummary> summary(DateTime month) async {
    final res = await _client.dio.get(
      '/personal-expenses/summary',
      queryParameters: {
        'month':
            '${month.year}-${month.month.toString().padLeft(2, '0')}',
        'tzOffset': DateTime.now().timeZoneOffset.inMinutes,
      },
    );
    return PersonalSummary.fromJson(_ensureMap(res));
  }

  Future<PersonalExpenseModel> getById(String id) async {
    final res = await _client.dio.get('/personal-expenses/$id');
    final data = _ensureMap(res);
    return PersonalExpenseModel.fromJson(data);
  }

  Future<PersonalExpenseModel> create({
    required String description,
    required double amount,
    String currency = 'INR',
    String? category,
    String? notes,
    DateTime? expenseDate,
    String? receiptBase64,
    bool isIncome = false,
    String? accountId,
  }) async {
    final res = await _client.dio.post(
      '/personal-expenses',
      data: {
        if (isIncome) 'kind': 'income',
        if (accountId != null) 'accountId': accountId,
        'description': description,
        'amount': amount,
        'currency': _normalizeCurrency(currency),
        if (category != null) 'category': category,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (expenseDate != null)
          'expenseDate': expenseDate.toIso8601String(),
        if (receiptBase64 != null) 'receiptBase64': receiptBase64,
      },
    );
    final data = _ensureMap(res);
    return PersonalExpenseModel.fromJson(data);
  }

  Future<PersonalExpenseModel> update(
    String id, {
    String? description,
    double? amount,
    String? currency,
    String? category,
    String? notes,
    DateTime? expenseDate,
    String? receiptBase64,
  }) async {
    final res = await _client.dio.put(
      '/personal-expenses/$id',
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
    return PersonalExpenseModel.fromJson(data);
  }

  Future<void> delete(String id) async {
    final res = await _client.dio.delete('/personal-expenses/$id');
    _ensureSuccess(res);
  }

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
      throw PersonalExpensesApiException(msg, statusCode: res.statusCode);
    }
    return body.cast<String, dynamic>();
  }

  Map<String, dynamic> _ensureMap(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw PersonalExpensesApiException(
          'Malformed response: expected object in data');
    }
    return data;
  }

  List<dynamic> _ensureList(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! List) {
      throw PersonalExpensesApiException(
          'Malformed response: expected list in data');
    }
    return data;
  }
}

final personalExpensesRepositoryProvider =
    Provider<PersonalExpensesRepository>((ref) {
  return PersonalExpensesRepository(ref.watch(apiClientProvider));
});
