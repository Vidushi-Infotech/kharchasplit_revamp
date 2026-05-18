import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class ReportsApiException implements Exception {
  ReportsApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Snapshot returned by `GET /users/:id/reports?period=...`. Mirrors the
/// shape `ReportsData` expects so the screen wrapper is a near-passthrough.
class ReportsSummary {
  const ReportsSummary({
    required this.period,
    required this.totalSpending,
    required this.youOwe,
    required this.owedToYou,
    required this.categorySpending,
    required this.monthlySpending,
    required this.topCategories,
  });

  final String period;
  final double totalSpending;
  final double youOwe;
  final double owedToYou;

  /// categoryId → amount the caller consumed within the window.
  final Map<String, double> categorySpending;

  /// 'YYYY-MM' → amount. Sparse — months with zero spend are absent.
  final Map<String, double> monthlySpending;

  /// Top 5 categories sorted descending by amount.
  final List<ReportsCategoryRow> topCategories;
}

class ReportsCategoryRow {
  const ReportsCategoryRow({required this.categoryId, required this.amount});
  final String categoryId;
  final double amount;
}

class ReportsRepository {
  ReportsRepository(this._client);
  final ApiClient _client;

  Future<ReportsSummary> getForUser(String userId, {String period = 'month'}) async {
    final res = await _client.dio.get(
      '/users/$userId/reports',
      queryParameters: {'period': period},
    );
    final data = _ensureSuccess(res);

    Map<String, double> parseAmountMap(dynamic raw) {
      if (raw is! Map) return <String, double>{};
      final out = <String, double>{};
      raw.forEach((k, v) {
        if (k is String) {
          final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
          out[k] = d;
        }
      });
      return out;
    }

    final topRaw = data['topCategories'];
    final top = topRaw is List
        ? topRaw
            .whereType<Map>()
            .map((m) => ReportsCategoryRow(
                  categoryId: (m['category'] ?? 'other').toString(),
                  amount: (m['amount'] is num)
                      ? (m['amount'] as num).toDouble()
                      : double.tryParse((m['amount'] ?? '0').toString()) ?? 0,
                ))
            .toList()
        : <ReportsCategoryRow>[];

    return ReportsSummary(
      period: (data['period'] ?? period).toString(),
      totalSpending: (data['totalSpending'] as num?)?.toDouble() ?? 0,
      youOwe: (data['youOwe'] as num?)?.toDouble() ?? 0,
      owedToYou: (data['owedToYou'] as num?)?.toDouble() ?? 0,
      categorySpending: parseAmountMap(data['categorySpending']),
      monthlySpending: parseAmountMap(data['monthlySpending']),
      topCategories: top,
    );
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw ReportsApiException(msg, statusCode: res.statusCode);
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ReportsApiException('Malformed response — expected object in data');
    }
    return data;
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});
