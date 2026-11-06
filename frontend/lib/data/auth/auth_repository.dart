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

  /// True when register/verify just created the user row.
  final bool isNewUser;

  /// True when the client should route to the profile-setup screen
  /// before showing the main app (brand-new user, or existing row missing
  /// name/email).
  final bool needsProfileSetup;
}

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  /// Register with phone + password. Backend returns tokens immediately;
  /// `needsProfileSetup` will be true so the UI routes to /profile-setup.
  Future<AuthTokens> registerWithPassword({
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    final device = await DeviceInfoService.describe();
    final res = await _client.dio.post(
      '/auth/register',
      data: {
        'phoneNumber': phoneNumber,
        'password': password,
        'confirmPassword': confirmPassword,
        if (device.isNotEmpty) 'device': device,
      },
    );
    final data = _ensureSuccess(res);
    return _tokensFromData(data);
  }

  /// Phone + password login. Returns tokens + user on success.
  Future<AuthTokens> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    final device = await DeviceInfoService.describe();
    final res = await _client.dio.post(
      '/auth/login',
      data: {
        'phoneNumber': phoneNumber,
        'password': password,
        if (device.isNotEmpty) 'device': device,
      },
    );
    final data = _ensureSuccess(res);
    return _tokensFromData(data);
  }

  /// Request a password-reset OTP via email. The backend always returns a
  /// generic success message — we never tell the caller whether the email
  /// is registered, so no enumeration is possible from this response.
  Future<void> requestPasswordReset(String email) async {
    final res = await _client.dio.post(
      '/auth/forgot-password/request',
      data: {'email': email},
    );
    _ensureSuccess(res);
  }

  /// Verify the OTP + set the new password. On success the backend
  /// auto-logs in and returns a fresh token pair.
  Future<AuthTokens> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final device = await DeviceInfoService.describe();
    final res = await _client.dio.post(
      '/auth/forgot-password/verify',
      data: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
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
