import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_config.dart';
import '../services/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.read(tokenStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});

class ApiClient {
  ApiClient(this.tokens) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: 'application/json',
      responseType: ResponseType.json,
      validateStatus: (s) => s != null && s < 500,
    ));
    dio.interceptors.add(_AuthInterceptor(this));
  }

  late final Dio dio;
  final TokenStorage tokens;
  final _unauthorizedController = StreamController<void>.broadcast();
  Completer<bool>? _refreshing;

  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  Future<bool> refreshAccessToken() {
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<bool>();
    _refreshing = completer;
    _doRefresh().then((ok) {
      completer.complete(ok);
    }).whenComplete(() {
      _refreshing = null;
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data is Map ? res.data['data'] as Map? : null;
      final newAccess = data?['accessToken'] as String?;
      if (newAccess == null) return false;
      await tokens.saveTokens(
        accessToken: newAccess,
        refreshToken: refreshToken,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  void dispose() {
    _unauthorizedController.close();
    dio.close(force: true);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.client);
  final ApiClient client;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await client.tokens.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.statusCode == 401 &&
        !response.requestOptions.path.contains('/auth/refresh') &&
        response.requestOptions.extra['_retried'] != true) {
      final ok = await client.refreshAccessToken();
      if (ok) {
        response.requestOptions.extra['_retried'] = true;
        try {
          final retry = await client.dio.fetch(response.requestOptions);
          return handler.resolve(retry);
        } on DioException catch (e) {
          return handler.reject(e);
        }
      }
      await client.tokens.clear();
      client._unauthorizedController.add(null);
    }
    handler.next(response);
  }
}
