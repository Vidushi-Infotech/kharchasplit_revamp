import 'dart:async';

import 'package:dio/dio.dart';

/// Retries *idempotent* requests that failed for transient reasons.
///
/// Scope is deliberately narrow:
/// * Only `GET` / `HEAD`. A `POST /expenses` that timed out may well have
///   been applied server-side; replaying it would double-book the expense.
///   Mutations get no automatic retry until the backend supports an
///   `Idempotency-Key` header.
/// * Only transient failures — connect / send / receive timeouts, socket
///   errors, and 502 / 503 / 504. A 4xx or a 500 is not going to fix itself.
/// * Never when we already know we're offline. [OfflineInterceptor] rejects
///   those with `error == 'offline'` before a socket is even opened; retrying
///   would just re-hit the same fast-fail.
/// * Short, bounded backoff: [delays] defaults to 1 s then 2 s, so the worst
///   case adds ~3 s on top of the request's own timeouts.
///
/// Opt a single request out with `options.extra['noRetry'] = true`.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.delays = const [Duration(seconds: 1), Duration(seconds: 2)],
  });

  final Dio _dio;
  final List<Duration> delays;

  static const _attemptKey = '_retryAttempt';
  static const _retryableStatus = {502, 503, 504};
  static const _retryableTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (!_shouldRetry(err) || attempt >= delays.length) {
      return handler.next(err);
    }

    await Future<void>.delayed(delays[attempt]);
    options.extra[_attemptKey] = attempt + 1;
    try {
      // fetch() re-runs the full interceptor chain, so the offline check and
      // the auth header are re-applied on the retry.
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    final options = err.requestOptions;
    if (options.extra['noRetry'] == true) return false;
    final method = options.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') return false;
    if (err.error == 'offline') return false;

    if (_retryableTypes.contains(err.type)) return true;
    if (err.type == DioExceptionType.badResponse) {
      return _retryableStatus.contains(err.response?.statusCode);
    }
    return false;
  }
}
