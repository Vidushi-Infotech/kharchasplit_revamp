import 'package:dio/dio.dart';

import '../services/connectivity_service.dart';

/// Dio interceptor that:
/// 1. Fails outgoing requests *immediately* when [ConnectivityService]
///    already knows we're offline — avoids the 10-second OS-level DNS /
///    socket timeout. The Dart-side error type matches what a real
///    timeout would have produced, so existing error handlers (e.g.
///    AuthRepository._readableError) keep working.
/// 2. On response errors that look like connectivity failures, triggers
///    a re-read of the OS connectivity state. This handles the
///    "captive-portal" case where the OS reports online but real network
///    calls fail — the recheck will downgrade to offline on next event
///    if the OS confirms, but more importantly it makes the banner
///    self-correct after a real connection-error.
class OfflineInterceptor extends Interceptor {
  OfflineInterceptor(this._service);

  final ConnectivityService _service;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_service.current == ConnectivityState.offline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'offline',
          message: 'No internet connection',
        ),
        true, // prevent further interceptors from running
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isConnectivityIssue =
        err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout;
    if (isConnectivityIssue) {
      // Fire and forget — banner state will refresh on the next emit.
      _service.recheck();
    }
    handler.next(err);
  }
}
