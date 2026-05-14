import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../models/user_model.dart';

enum AuthState { initial, loading, success, error }

class AuthData {
  const AuthData({
    this.state = AuthState.initial,
    this.user,
    this.errorMessage,
    this.successMessage,
  });

  final AuthState state;
  final UserModel? user;
  final String? errorMessage;
  final String? successMessage;

  bool get isAuthenticated => user != null;

  AuthData copyWith({
    AuthState? state,
    UserModel? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return AuthData(
      state: state ?? this.state,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthData>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthData> {
  late final AuthRepository _repo = ref.read(authRepositoryProvider);
  late final ApiClient _apiClient = ref.read(apiClientProvider);

  @override
  AuthData build() {
    _hydrateFromStorage();
    return const AuthData();
  }

  Future<void> _hydrateFromStorage() async {
    final stored = await _apiClient.tokens.readUser();
    if (stored == null) return;
    try {
      final user = UserModel.fromJson(stored);
      state = state.copyWith(user: user);
    } catch (_) {
      // Stored payload no longer matches model — drop it silently.
      await _apiClient.tokens.clear();
    }
  }

  /// Step 1 of registration: create the user record. Backend sends an OTP.
  Future<bool> register({
    required String name,
    required String phone,
    String? email,
  }) async {
    state = state.copyWith(
      state: AuthState.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final normalized = _normalizePhone(phone);
      await _repo.register(
        phoneNumber: normalized,
        name: name.trim(),
        email: email?.trim().isEmpty == true ? null : email?.trim(),
      );
      state = state.copyWith(
        state: AuthState.success,
        successMessage: 'OTP sent to your phone',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: _readableError(e),
      );
      return false;
    }
  }

  /// Login step 1: request an OTP for an existing user.
  Future<bool> requestLoginOtp(String phone) async {
    state = state.copyWith(
      state: AuthState.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final normalized = _normalizePhone(phone);
      await _repo.sendLoginOtp(normalized);
      state = state.copyWith(
        state: AuthState.success,
        successMessage: 'OTP sent to your phone',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: _readableError(e),
      );
      return false;
    }
  }

  /// Step 2 (login or registration): verify OTP, persist tokens, set user.
  Future<bool> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    state = state.copyWith(
      state: AuthState.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final normalized = _normalizePhone(phone);
      final result = await _repo.verifyOtp(
        phoneNumber: normalized,
        otp: otp.trim(),
      );
      await _apiClient.tokens.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await _apiClient.tokens.saveUser(result.user);
      final user = UserModel.fromJson(result.user);
      state = AuthData(state: AuthState.success, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: _readableError(e),
      );
      return false;
    }
  }

  /// PUT /users/:id — updates the current user's name, email, and/or photo.
  /// Returns true on success and refreshes the local [AuthData.user].
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? profileImageBase64,
    String? preferredCurrency,
  }) async {
    final user = state.user;
    if (user == null) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: 'Not signed in',
      );
      return false;
    }
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (email != null) payload['email'] = email.trim();
    if (profileImageBase64 != null) {
      payload['profileImageBase64'] = profileImageBase64;
    }
    if (preferredCurrency != null) {
      payload['preferredCurrency'] = preferredCurrency;
    }
    if (payload.isEmpty) return true;

    state = state.copyWith(state: AuthState.loading, clearError: true);
    try {
      final res = await _apiClient.dio.put(
        '/users/${user.id}',
        data: payload,
      );
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      if (data is Map<String, dynamic>) {
        await _apiClient.tokens.saveUser(data);
      }
      final updated = data is Map<String, dynamic>
          ? UserModel.fromJson(data)
          : user.copyWith(
              name: (payload['name'] as String?) ?? user.name,
              email: (payload['email'] as String?) ?? user.email,
              preferredCurrency:
                  (payload['preferredCurrency'] as String?) ??
                      user.preferredCurrency,
            );
      state = state.copyWith(
        state: AuthState.success,
        user: updated,
        successMessage: 'Profile updated',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: _readableError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    final refresh = await _apiClient.tokens.readRefreshToken();
    if (refresh != null) {
      await _repo.logout(refresh);
    }
    await _apiClient.tokens.clear();
    state = const AuthData();
  }

  /// Permanently deletes the user's account on the backend, then clears
  /// local tokens and auth state. Throws on backend failure so the caller
  /// can show an error.
  Future<void> deleteAccount() async {
    final user = state.user;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final res = await _apiClient.dio.delete('/users/${user.id}');
    final body = res.data;
    if (body is Map && body['success'] != true) {
      throw Exception(body['error']?.toString() ?? 'Account deletion failed');
    }
    await _apiClient.tokens.clear();
    state = const AuthData();
  }

  /// Revokes every active session for this account on every device,
  /// clears local tokens, and resets auth state. Returns the number of
  /// sessions that were ended (including this one).
  Future<int> signOutEverywhere() async {
    int revoked = 0;
    try {
      // Calling DELETE /auth/sessions without `keepRefreshToken` revokes ALL.
      final res = await _apiClient.dio.delete('/auth/sessions');
      final body = res.data;
      if (body is Map &&
          body['data'] is Map &&
          (body['data'] as Map)['revokedCount'] is int) {
        revoked = (body['data'] as Map)['revokedCount'] as int;
      }
    } catch (_) {
      // Best-effort: even if the server call fails we still clear locally so
      // the user is signed out on this device.
    }
    await _apiClient.tokens.clear();
    state = const AuthData();
    return revoked;
  }

  void clearMessages() {
    state = state.copyWith(
      state: AuthState.initial,
      clearError: true,
      clearSuccess: true,
    );
  }

  /// Backend expects E.164 (`^\+?[1-9]\d{1,14}$`). For convenience the UI
  /// accepts a bare 10-digit Indian mobile number and we prepend +91 here.
  String _normalizePhone(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (RegExp(r'^\d{10}$').hasMatch(cleaned)) return '+91$cleaned';
    return cleaned;
  }

  String _readableError(Object e) {
    if (e is AuthException) return e.message;
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map && body['error'] is String) return body['error'] as String;
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Could not reach the server. Check your connection.';
      }
      return e.message ?? 'Network request failed';
    }
    return e.toString();
  }
}
