import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'token_storage.dart';

/// Singleton Dio instance with auth token interceptors
class ApiClient {
  late Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.timeout,
        receiveTimeout: ApiConfig.timeout,
        sendTimeout: ApiConfig.timeout,
        headers: {
          'Content-Type': ApiConfig.contentType,
          'Accept': ApiConfig.contentType,
        },
      ),
    );

    // Request interceptor to add auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await tokenStorage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            print('[ApiClient] Error reading token: $e');
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized with token refresh
          if (error.response?.statusCode == 401 &&
              error.requestOptions.path != '/auth/refresh') {
            try {
              final refreshToken = await tokenStorage.getRefreshToken();
              if (refreshToken != null && refreshToken.isNotEmpty) {
                print('[ApiClient] Token expired, attempting refresh...');

                // Refresh token
                final response = await _refreshToken(refreshToken);

                if (response.statusCode == 200 && response.data['success']) {
                  final newAccessToken =
                      response.data['data']['accessToken'];
                  await tokenStorage.saveAccessToken(newAccessToken);

                  // Retry original request with new token
                  final requestOptions = error.requestOptions;
                  final retryOptions = Options(
                    method: requestOptions.method,
                    headers: {...?requestOptions.headers, 'Authorization': 'Bearer $newAccessToken'},
                  );

                  print('[ApiClient] Token refreshed, retrying request...');
                  return handler.resolve(
                    await _dio.request(
                      requestOptions.path,
                      data: requestOptions.data,
                      queryParameters: requestOptions.queryParameters,
                      options: retryOptions,
                    ),
                  );
                }
              }
            } catch (e) {
              print('[ApiClient] Token refresh failed: $e');
            }

            // If refresh fails, clear tokens and logout
            await tokenStorage.clearTokens();
          }

          return handler.next(error);
        },
      ),
    );

    // Logging interceptor (development only)
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (log) {
          print('[ApiClient] $log');
        },
      ),
    );
  }

  Future<Response> _refreshToken(String refreshToken) {
    return Dio().post(
      '${ApiConfig.baseUrl}/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(
        contentType: ApiConfig.contentType,
      ),
    );
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    required dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    required dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    required dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

/// Singleton instance
final apiClient = ApiClient();
