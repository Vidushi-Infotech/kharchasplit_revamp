import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/push_service.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../models/user_model.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';

enum AuthState { initial, loading, success, error }

class AuthData {
  const AuthData({
    this.state = AuthState.initial,
    this.user,
    this.errorMessage,
    this.successMessage,
    this.needsProfileSetup = false,
  });

  final AuthState state;
  final UserModel? user;
  final String? errorMessage;
  final String? successMessage;

  /// Set true after register/login if the row is missing name or email
  /// (brand new user, or existing user who never completed setup). The
  /// router uses this to send them to ProfileSetupScreen instead of the
  /// dashboard.
  final bool needsProfileSetup;

  bool get isAuthenticated => user != null;

  AuthData copyWith({
    AuthState? state,
    UserModel? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    bool? needsProfileSetup,
  }) {
    return AuthData(
      state: state ?? this.state,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      needsProfileSetup: needsProfileSetup ?? this.needsProfileSetup,
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
      // Fetch fresh data from server in background to sync across devices.
      unawaited(_refreshFromServer(user.id));
    } catch (_) {
      // Stored payload no longer matches model — drop it silently.
      await _apiClient.tokens.clear();
    }
  }

  /// Fetches the latest user profile from the backend and updates
  /// local storage + state. Keeps profile data in sync across devices.
  Future<void> _refreshFromServer(String userId) async {
    try {
      final res = await _apiClient.dio.get('/users/$userId');
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      if (data is Map<String, dynamic>) {
        final fresh = UserModel.fromJson(data);
        final current = state.user;
        // Don't overwrite richer local data with empty server data.
        // This guards against the case where a profile update was saved
        // locally but the server didn't receive it (e.g. proxy blocking PUT).
        if (current != null &&
            current.name.trim().isNotEmpty &&
            fresh.name.trim().isEmpty) {
          return;
        }
        await _apiClient.tokens.saveUser(fresh.toJson());
        state = state.copyWith(user: fresh);
      }
    } catch (_) {
      // Best-effort — don't break the app if server is unreachable.
    }
  }

  /// Public refresh for pull-to-refresh on profile screen.
  Future<void> refreshProfile() async {
    final user = state.user;
    if (user == null) return;
    await _refreshFromServer(user.id);
  }

  /// Register with phone + password. On success the backend signs the user
  /// in immediately; we persist tokens and set `needsProfileSetup` so the
  /// UI routes to /profile-setup before the dashboard.
  Future<bool> registerWithPassword({
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(
      state: AuthState.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final normalized = _normalizePhone(phone);
      final result = await _repo.registerWithPassword(
        phoneNumber: normalized,
        password: password,
        confirmPassword: confirmPassword,
      );
      await _persistAuthResult(result);
      return true;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: _readableError(e),
      );
      return false;
    }
  }

  /// Phone + password login.
  Future<bool> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(
      state: AuthState.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final normalized = _normalizePhone(phone);
      final result = await _repo.loginWithPassword(
        phoneNumber: normalized,
        password: password,
      );
      await _persistAuthResult(result);
      return true;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: _readableError(e),
      );
      return false;
    }
  }

  /// Forgot-password step 1: ask backend to email an OTP.
  /// Returns true on a successful network round-trip; the response is
  /// intentionally generic ("if registered, a code was sent") so the user
  /// can't enumerate accounts.
  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(
      state: AuthState.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repo.requestPasswordReset(email.trim());
      state = state.copyWith(
        state: AuthState.success,
        successMessage: 'If that email is registered, a code has been sent.',
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

  /// Forgot-password step 2: verify the OTP and set the new password. On
  /// success the backend issues a fresh token pair (auto-login).
  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(
      state: AuthState.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final result = await _repo.resetPassword(
        email: email.trim(),
        otp: otp.trim(),
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      await _persistAuthResult(result);
      return true;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: _readableError(e),
      );
      return false;
    }
  }

  /// Save tokens + user, then update state and kick off FCM registration.
  Future<void> _persistAuthResult(AuthTokens result) async {
    await _apiClient.tokens.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await _apiClient.tokens.saveUser(result.user);
    final user = UserModel.fromJson(result.user);
    state = AuthData(
      state: AuthState.success,
      user: user,
      needsProfileSetup: result.needsProfileSetup,
    );
    if (PushService.isSupportedPlatform) {
      unawaited(PushService.instance.registerWithBackend(
        dio: _apiClient.dio,
        userId: user.id,
      ));
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
      final updated = data is Map<String, dynamic>
          ? UserModel.fromJson(data)
          : user.copyWith(
              name: (payload['name'] as String?) ?? user.name,
              email: (payload['email'] as String?) ?? user.email,
              avatarUrl: (payload['profileImageBase64'] as String?) ??
                  user.avatarUrl,
              preferredCurrency:
                  (payload['preferredCurrency'] as String?) ??
                      user.preferredCurrency,
            );
      await _apiClient.tokens.saveUser(updated.toJson());
      // Profile setup is complete once both a name and an email are on
      // file (email is required so the user can receive password-reset OTPs).
      final clearedSetup = updated.name.trim().isNotEmpty &&
          updated.email.trim().isNotEmpty;
      state = state.copyWith(
        state: AuthState.success,
        user: updated,
        successMessage: 'Profile updated',
        needsProfileSetup: clearedSetup ? false : null,
      );
      // Invalidate group caches so member avatars/names refresh.
      // Deferred to avoid re-entrant build (groupsProvider watches authProvider).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(groupsProvider);
        ref.invalidate(groupDetailProvider);
      });
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
    // Unregister this device's FCM token before clearing auth so the
    // server stops sending to a logged-out device.
    final user = state.user;
    if (user != null && PushService.isSupportedPlatform) {
      try {
        await PushService.instance.unregisterFromBackend(
          dio: _apiClient.dio,
          userId: user.id,
        );
      } catch (_) {/* don't block logout on unregister failure */}
    }
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
