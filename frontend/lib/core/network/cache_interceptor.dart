import 'dart:convert';

import 'package:dio/dio.dart';

import '../services/connectivity_service.dart';
import '../services/token_storage.dart';
import '../state/offline_data.dart';
import '../storage/local_store.dart';
import 'cache_policy.dart';

const _keyExtra = 'cacheKey';

/// Keeps the last good response of read-only GETs ([CachePolicy]) on the
/// device and serves it when there's no connection, so lists, balances and
/// expenses still open offline. Responses served from the cache carry
/// `extra['fromCache'] = true` and `extra['cachedAt']`; repositories and
/// providers need no changes.
///
/// Two interceptors: [CacheInterceptor] goes first (stores fresh responses;
/// answers straight from the cache when the device is known to be
/// offline), [CacheFallbackInterceptor] goes last (answers from the cache
/// when a request failed for connectivity reasons after the retries).
class CacheInterceptor extends Interceptor {
  CacheInterceptor(this._tokens, this._connectivity);

  final TokenStorage _tokens;
  final ConnectivityService _connectivity;

  String? _userId;
  DateTime _userReadAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// The signed-in user's id (memoised briefly — it's read per request).
  Future<String?> _currentUserId() async {
    if (DateTime.now().difference(_userReadAt) > const Duration(seconds: 5)) {
      final user = await _tokens.readUser();
      _userId = (user?['id'] ?? user?['userId']) as String?;
      _userReadAt = DateTime.now();
    }
    return _userId;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method.toUpperCase() == 'GET' &&
        LocalStore.box(LocalStore.httpCacheBox) != null) {
      final key = CachePolicy.keyFor(
        userId: await _currentUserId(),
        path: options.path,
        queryParameters: options.queryParameters,
      );
      if (key != null) {
        options.extra[_keyExtra] = key;
        if (_connectivity.current == ConnectivityState.offline) {
          final cached = cachedResponse(options);
          if (cached != null) return handler.resolve(cached);
        }
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = response.requestOptions.extra[_keyExtra] as String?;
    final box = LocalStore.box(LocalStore.httpCacheBox);
    final status = response.statusCode ?? 0;
    final data = response.data;
    if (key != null &&
        box != null &&
        response.extra['fromCache'] != true &&
        status >= 200 &&
        status < 300 &&
        data is Map &&
        data['success'] == true) {
      try {
        final raw = '{"savedAt":${DateTime.now().millisecondsSinceEpoch},'
            '"statusCode":$status,"data":${jsonEncode(data)}}';
        if (raw.length <= CachePolicy.maxEntryChars) {
          box.put(key, raw);
          _evictIfNeeded();
        }
      } catch (_) {/* unencodable — just don't cache */}
      OfflineData.instance.fresh(key);
    }
    handler.next(response);
  }

  int _writesSinceEvict = 0;

  void _evictIfNeeded() {
    if (++_writesSinceEvict < 20) return;
    _writesSinceEvict = 0;
    final box = LocalStore.box(LocalStore.httpCacheBox);
    if (box == null || box.length <= CachePolicy.maxEntries) return;
    final ages = {
      for (final k in box.keys.cast<String>()) k: CachePolicy.savedAtOf(box.get(k) ?? ''),
    };
    box.deleteAll(CachePolicy.keysToEvict(ages));
  }
}

/// Last in the chain: a GET that still failed for lack of a connection is
/// answered from the cache when there is an entry.
class CacheFallbackInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isConnectivity = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout;
    if (isConnectivity && err.requestOptions.method.toUpperCase() == 'GET') {
      final cached = cachedResponse(err.requestOptions);
      if (cached != null) return handler.resolve(cached);
    }
    handler.next(err);
  }
}

/// The stored response for [options] (keyed by [CacheInterceptor]), or
/// null. Reports what it served to [OfflineData].
Response<dynamic>? cachedResponse(RequestOptions options) {
  final key = options.extra[_keyExtra] as String?;
  final raw = key == null ? null : LocalStore.box(LocalStore.httpCacheBox)?.get(key);
  if (raw == null) return null;
  try {
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final savedAt = DateTime.fromMillisecondsSinceEpoch(entry['savedAt'] as int);
    OfflineData.instance.servedFromCache(key!, savedAt);
    return Response(
      requestOptions: options,
      statusCode: entry['statusCode'] as int? ?? 200,
      data: entry['data'],
      extra: {'fromCache': true, 'cachedAt': savedAt},
    );
  } catch (_) {
    return null;
  }
}
