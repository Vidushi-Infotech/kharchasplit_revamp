import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/services/device_info_service.dart';

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.isNewUser = false,
    this.needsProfileSetup = false,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  /// True when verify-otp auto-created the user row.
  final bool isNewUser;

  /// True when the client should route to the profile-setup screen
  /// before showing the main app (covers both brand-new users and
  /// existing users with an empty name).
  final bool needsProfileSetup;
}

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  Future<void> register({
    required String phoneNumber,
    required String name,
    String? email,
  }) async {
    final res = await _client.dio.post(
      '/auth/register',
      data: {
        'phoneNumber': phoneNumber,
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    _ensureSuccess(res);
  }

  Future<void> sendLoginOtp(String phoneNumber) async {
    final res = await _client.dio.post(
      '/auth/send-otp',
      data: {'phoneNumber': phoneNumber},
    );
    _ensureSuccess(res);
  }

  Future<AuthTokens> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final device = await DeviceInfoService.describe();
    final res = await _client.dio.post(
      '/auth/verify-otp',
      data: {
        'phoneNumber': phoneNumber,
        'otp': otp,
        if (device.isNotEmpty) 'device': device,
      },
    );
    final data = _ensureSuccess(res);
    return _tokensFromData(data);
  }

  Future<AuthTokens> simpleLogin(String phoneNumber) async {
    final device = await DeviceInfoService.describe();
    final res = await _client.dio.post(
      '/auth/simple-login',
      data: {
        'phoneNumber': phoneNumber,
        if (device.isNotEmpty) 'device': device,
      },
    );
    final data = _ensureSuccess(res);
    return _tokensFromData(data);
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _client.dio.post(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      // Best-effort — clearing local state happens regardless.
    }
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    final ok = body is Map && body['success'] == true;
    if (!ok) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw AuthException(msg, statusCode: res.statusCode);
    }
    final data = body['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  AuthTokens _tokensFromData(Map<String, dynamic> data) {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    final user = data['user'];
    if (access == null || refresh == null || user is! Map<String, dynamic>) {
      throw AuthException('Malformed auth response from server');
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      user: user,
      isNewUser: data['isNewUser'] == true,
      needsProfileSetup: data['needsProfileSetup'] == true,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
