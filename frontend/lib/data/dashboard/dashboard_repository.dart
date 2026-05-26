import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/expense_model.dart';

class DashboardApiException implements Exception {
  DashboardApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DashboardSummary {
  const DashboardSummary({
    required this.youAreOwed,
    required this.youOwe,
    required this.totalBalance,
    required this.recentExpenses,
  });

  final double youAreOwed;
  final double youOwe;
  final double totalBalance;
  final List<ExpenseModel> recentExpenses;

  static const empty = DashboardSummary(
    youAreOwed: 0,
    youOwe: 0,
    totalBalance: 0,
    recentExpenses: <ExpenseModel>[],
  );
}

class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;

  Future<DashboardSummary> getForUser(String userId, {int recentLimit = 10}) async {
    final res = await _client.dio.get(
      '/users/$userId/dashboard',
      queryParameters: {'recentLimit': recentLimit},
    );
    final data = _ensureSuccess(res);
    final rawExpenses = data['recentExpenses'];
    final expenses = rawExpenses is List
        ? rawExpenses
            .whereType<Map<String, dynamic>>()
            .map(ExpenseModel.fromJson)
            .toList()
        : <ExpenseModel>[];
    return DashboardSummary(
      youAreOwed: (data['youAreOwed'] as num?)?.toDouble() ?? 0,
      youOwe: (data['youOwe'] as num?)?.toDouble() ?? 0,
      totalBalance: (data['totalBalance'] as num?)?.toDouble() ?? 0,
      recentExpenses: expenses,
    );
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw DashboardApiException(msg, statusCode: res.statusCode);
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw DashboardApiException('Malformed dashboard response');
    }
    return data;
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});
