import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth state enum
enum AuthState { initial, loading, success, error }

/// Auth data model
class AuthData {
  final AuthState state;
  final String? errorMessage;
  final String? successMessage;

  const AuthData({
    this.state = AuthState.initial,
    this.errorMessage,
    this.successMessage,
  });

  AuthData copyWith({
    AuthState? state,
    String? errorMessage,
    String? successMessage,
  }) {
    return AuthData(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

/// Auth provider for managing authentication state (Riverpod 3.x)
final authProvider = NotifierProvider<AuthNotifier, AuthData>(
  AuthNotifier.new,
);

/// Auth state notifier
class AuthNotifier extends Notifier<AuthData> {
  @override
  AuthData build() => const AuthData();

  /// Register user
  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    String? referralCode,
  }) async {
    state = state.copyWith(state: AuthState.loading);

    try {
      // Validate inputs
      if (fullName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
        throw Exception('All fields are required');
      }

      if (password != confirmPassword) {
        throw Exception('Passwords do not match');
      }

      if (password.length < 8) {
        throw Exception('Password must be at least 8 characters');
      }

      // TODO: Implement actual registration API call
      await Future.delayed(const Duration(seconds: 2));

      state = state.copyWith(
        state: AuthState.success,
        successMessage: 'Registration successful',
      );
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Reset auth state
  void reset() {
    state = const AuthData();
  }
}
