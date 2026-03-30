import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_api_service.dart';

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

      if (phone.length != 10) {
        throw Exception('Please enter a valid 10-digit phone number');
      }

      // Call backend API to register
      final result = await AuthApiService.register(
        phoneNumber: phone,
        name: fullName,
        email: email,
      );

      if (result['success'] == true) {
        state = state.copyWith(
          state: AuthState.success,
          successMessage: 'Registration successful. Please verify your OTP.',
        );
      } else {
        throw Exception(result['message'] ?? 'Registration failed');
      }
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Login user with phone number (simple login - no password)
  /// Backend checks if user exists and returns tokens
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(state: AuthState.loading);

    try {
      // For now, we use the "email" field as phone number for backend compatibility
      // TODO: Refactor to use phone field directly
      final phoneNumber = email.isEmpty ? password : email;

      if (phoneNumber.isEmpty) {
        throw Exception('Phone number is required');
      }

      if (phoneNumber.length != 10 && !phoneNumber.startsWith('+91')) {
        throw Exception('Please enter a valid 10-digit phone number');
      }

      // Call backend API to login
      final result = await AuthApiService.simpleLogin(
        phoneNumber: phoneNumber,
      );

      if (result['success'] == true && result['userExists'] == true) {
        state = state.copyWith(
          state: AuthState.success,
          successMessage: 'Login successful',
        );
      } else if (result['userExists'] == false) {
        throw Exception('User not found. Please register first.');
      } else {
        throw Exception(result['message'] ?? 'Login failed');
      }
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Reset password with email and code
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(state: AuthState.loading);

    try {
      // Validate inputs
      if (email.isEmpty || code.isEmpty || newPassword.isEmpty) {
        throw Exception('All fields are required');
      }

      if (!email.contains('@')) {
        throw Exception('Invalid email format');
      }

      if (newPassword.length < 8) {
        throw Exception('Password must be at least 8 characters');
      }

      // TODO: Implement actual password reset API call
      // Expected endpoint: POST /auth/reset-password
      // Params: { email, resetCode, newPassword }
      await Future.delayed(const Duration(seconds: 2));

      state = state.copyWith(
        state: AuthState.success,
        successMessage: 'Password reset successful',
      );
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(state: AuthState.loading);

    try {
      // TODO: Implement actual Google sign-in with google_sign_in package
      await Future.delayed(const Duration(seconds: 2));

      state = state.copyWith(
        state: AuthState.success,
        successMessage: 'Google sign-in successful',
      );
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: 'Google sign-in failed: ${e.toString()}',
      );
    }
  }

  /// Sign in with Facebook
  Future<void> signInWithFacebook() async {
    state = state.copyWith(state: AuthState.loading);

    try {
      // TODO: Implement actual Facebook sign-in with flutter_facebook_auth package
      await Future.delayed(const Duration(seconds: 2));

      state = state.copyWith(
        state: AuthState.success,
        successMessage: 'Facebook sign-in successful',
      );
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: 'Facebook sign-in failed: ${e.toString()}',
      );
    }
  }

  /// Reset auth state
  void reset() {
    state = const AuthData();
  }
}
