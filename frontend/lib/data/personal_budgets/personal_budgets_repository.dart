import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/personal_budget_model.dart';

/// Personal mode budgets: /personal-budgets.
class PersonalBudgetsRepository {
  PersonalBudgetsRepository(this._client);
  final ApiClient _client;

  /// Budgets and spending for the month containing [month], with days
  /// split at the phone's midnight.
  Future<BudgetsOverview> overview(DateTime month) async {
    final res = await _client.dio.get(
      '/personal-budgets',
      queryParameters: {
        'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
        'tzOffset': DateTime.now().timeZoneOffset.inMinutes,
      },
    );
    return BudgetsOverview.fromJson(_data(res));
  }

  Future<void> set(String category, double amount) async {
    final res = await _client.dio.put(
      '/personal-budgets/$category',
      data: {'amount': amount},
    );
    _data(res);
  }

  Future<void> remove(String category) async {
    final res = await _client.dio.delete('/personal-budgets/$category');
    _data(res);
  }

  Map<String, dynamic> _data(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      throw Exception(
        (body is Map ? body['error'] : null)?.toString() ??
            'Request failed (status ${res.statusCode})',
      );
    }
    final data = body['data'];
    return data is Map<String, dynamic> ? data : const {};
  }
}

final personalBudgetsRepositoryProvider = Provider<PersonalBudgetsRepository>(
  (ref) => PersonalBudgetsRepository(ref.watch(apiClientProvider)),
);
