import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// 1 [from] = [rate] [to], the reference rate for [date] (ECB, via the
/// server; weekends and holidays carry the previous working day's rate).
class FxRate {
  const FxRate({
    required this.from,
    required this.to,
    required this.rate,
    required this.date,
  });

  final String from;
  final String to;
  final double rate;

  /// 'YYYY-MM-DD' — never after today (a future expense uses today's rate).
  final String date;
}

/// No rate: currency not covered, or the rate service is down
/// (503 `FX_UNAVAILABLE`). The form then asks for the rate instead.
class FxUnavailableException implements Exception {
  const FxUnavailableException([this.message = 'Exchange rate unavailable']);
  final String message;

  @override
  String toString() => message;
}

class FxRepository {
  FxRepository(this._client);
  final ApiClient _client;

  /// GET /fx/rate — the live preview on the Add expense form. Throws
  /// [FxUnavailableException] on 503 (no retries: the form says "rate
  /// unavailable" straight away) and on anything malformed.
  Future<FxRate> rate({
    required String from,
    required String to,
    required DateTime date,
  }) async {
    final day =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    Response res;
    try {
      res = await _client.dio.get(
        '/fx/rate',
        queryParameters: {'from': from, 'to': to, 'date': day},
        options: Options(extra: {'noRetry': true}),
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      throw FxUnavailableException(
        body is Map && body['error'] is String
            ? body['error'] as String
            : 'Exchange rate unavailable',
      );
    }
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    final rate = data is Map ? num.tryParse('${data['rate']}') : null;
    if (body is! Map || body['success'] != true || rate == null || rate <= 0) {
      throw FxUnavailableException(
        body is Map && body['error'] is String
            ? body['error'] as String
            : 'Exchange rate unavailable',
      );
    }
    return FxRate(
      from: '${data!['from'] ?? from}',
      to: '${data['to'] ?? to}',
      rate: rate.toDouble(),
      date: '${data['date'] ?? day}',
    );
  }
}

final fxRepositoryProvider = Provider<FxRepository>((ref) {
  return FxRepository(ref.watch(apiClientProvider));
});
