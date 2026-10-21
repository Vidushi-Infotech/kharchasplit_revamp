import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Adds the request metadata the backend relies on.
///
/// * `X-App-Version` on every request, so the server can refuse writes from
///   app versions that would corrupt newer data (e.g. an old build editing
///   a multi-payer expense) and roll features out per version.
/// * `Idempotency-Key` on create requests. The key is stored on the
///   request options, so [RetryInterceptor]'s retries of the same request
///   reuse it and the server replays the first result instead of creating
///   a duplicate expense / settlement (backend middleware/idempotency.js).
class RequestMetaInterceptor extends Interceptor {
  static const idempotencyHeader = 'Idempotency-Key';

  /// POST endpoints the backend de-duplicates by Idempotency-Key.
  static const _idempotentPaths = {
    '/expenses',
    '/settlements',
    '/groups',
    '/personal-expenses',
  };

  static const _uuid = Uuid();
  String? _version;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    _version ??= await _loadVersion();
    if (_version != null) options.headers['X-App-Version'] = _version;

    if (options.method.toUpperCase() == 'POST' &&
        _idempotentPaths.contains(options.path) &&
        !options.headers.containsKey(idempotencyHeader)) {
      options.headers[idempotencyHeader] = _uuid.v4();
    }
    handler.next(options);
  }

  static Future<String?> _loadVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return null;
    }
  }
}
