import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/personal_bill_model.dart';

/// Personal mode bills: /personal-bills.
class PersonalBillsRepository {
  PersonalBillsRepository(this._client);
  final ApiClient _client;

  Future<List<PersonalBill>> list() async {
    final data = _body(await _client.dio.get('/personal-bills'))['data'];
    return data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(PersonalBill.fromJson)
              .toList()
        : const [];
  }

  /// Creates (no [id]) or changes a bill. A [dueDate] or [frequency] on a
  /// change restarts its schedule from that day, so leave them null when
  /// they didn't change.
  Future<void> save({
    String? id,
    required String name,
    required double amount,
    required String category,
    BillFrequency? frequency,
    DateTime? dueDate,
    required int remindDays,
    String? accountId,
  }) async {
    final data = {
      'name': name,
      'amount': amount,
      'category': category,
      if (frequency != null) 'frequency': frequency.name,
      if (dueDate != null) 'dueDate': _day(dueDate),
      'remindDays': remindDays,
      'accountId': accountId,
    };
    _body(
      id == null
          ? await _client.dio.post('/personal-bills', data: data)
          : await _client.dio.put('/personal-bills/$id', data: data),
    );
  }

  Future<void> archive(String id) async =>
      _body(await _client.dio.delete('/personal-bills/$id'));

  /// Records a payment (an expense) and moves the bill to its next date.
  Future<void> pay(String id, {double? amount, String? accountId}) async {
    _body(
      await _client.dio.post(
        '/personal-bills/$id/pay',
        data: {
          if (amount != null) 'amount': amount,
          if (accountId != null) 'accountId': accountId,
        },
      ),
    );
  }

  Future<void> skip(String id) async =>
      _body(await _client.dio.post('/personal-bills/$id/skip'));

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _body(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      throw Exception(
        (body is Map ? body['error'] : null)?.toString() ??
            'Request failed (status ${res.statusCode})',
      );
    }
    return body.cast<String, dynamic>();
  }
}

final personalBillsRepositoryProvider = Provider<PersonalBillsRepository>(
  (ref) => PersonalBillsRepository(ref.watch(apiClientProvider)),
);
