import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../../../models/user_model.dart';

/// Authentication API responses
class AuthApiResponse {
  final bool success;
  final String? message;
  final dynamic data;

  AuthApiResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory AuthApiResponse.fromJson(Map<String, dynamic> json) {
    return AuthApiResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'],
    );
  }
}

/// Authentication API Service
class AuthApiService {
  /// Register a new user with phone, name, and email
  static Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String name,
    required String email,
    String? profileImageBase64,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/register',
        data: {
          'phoneNumber': phoneNumber.startsWith('+91')
              ? phoneNumber
              : '+91$phoneNumber',
          'name': name,
          'email': email,
          if (profileImageBase64 != null) 'profileImageBase64': profileImageBase64,
        },
      );

      final result = AuthApiResponse.fromJson(response.data);
      return {
        'success': result.success,
        'message': result.message,
        'data': result.data,
      };
    } on DioException catch (e) {
      print('[AuthApiService] Register error: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? e.message,
        'error': e,
      };
    }
  }

  /// Send OTP to phone number
  static Future<Map<String, dynamic>> sendOTP({
    required String phoneNumber,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/send-otp',
        data: {
          'phoneNumber': phoneNumber.startsWith('+91')
              ? phoneNumber
              : '+91$phoneNumber',
        },
      );

      final result = AuthApiResponse.fromJson(response.data);
      return {
        'success': result.success,
        'message': result.message,
      };
    } on DioException catch (e) {
      print('[AuthApiService] Send OTP error: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? e.message,
        'error': e,
      };
    }
  }

  /// Verify OTP and login
  static Future<Map<String, dynamic>> verifyOTPAndLogin({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/verify-otp',
        data: {
          'phoneNumber': phoneNumber.startsWith('+91')
              ? phoneNumber
              : '+91$phoneNumber',
          'otp': otp,
        },
      );

      final result = AuthApiResponse.fromJson(response.data);

      if (result.success && result.data != null) {
        final data = result.data;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (accessToken != null && refreshToken != null && user != null) {
          await tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: user['id'] as String? ?? '',
          );
        }

        return {
          'success': true,
          'data': result.data,
        };
      }

      return {
        'success': false,
        'message': result.message ?? 'OTP verification failed',
      };
    } on DioException catch (e) {
      print('[AuthApiService] Verify OTP error: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? e.message,
        'error': e,
      };
    }
  }

  /// Simple login with phone number
  static Future<Map<String, dynamic>> simpleLogin({
    required String phoneNumber,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/simple-login',
        data: {
          'phoneNumber': phoneNumber.startsWith('+91')
              ? phoneNumber
              : '+91$phoneNumber',
        },
      );

      final result = AuthApiResponse.fromJson(response.data);

      if (result.success && result.data != null) {
        final data = result.data;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (accessToken != null && refreshToken != null && user != null) {
          await tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: user['id'] as String? ?? '',
          );
        }

        return {
          'success': true,
          'userExists': true,
          'data': result.data,
        };
      }

      return {
        'success': false,
        'userExists': false,
        'message': 'User not found',
      };
    } on DioException catch (e) {
      // 404 means user doesn't exist
      if (e.response?.statusCode == 404) {
        return {
          'success': false,
          'userExists': false,
          'message': 'User not found',
        };
      }

      print('[AuthApiService] Simple login error: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? e.message,
        'error': e,
      };
    }
  }

  /// Get current user profile
  static Future<Map<String, dynamic>> getUserProfile({
    required String userId,
  }) async {
    try {
      final response = await apiClient.get('/users/$userId');

      final result = AuthApiResponse.fromJson(response.data);
      return {
        'success': result.success,
        'data': result.data,
      };
    } on DioException catch (e) {
      print('[AuthApiService] Get user profile error: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? e.message,
        'error': e,
      };
    }
  }

  /// Logout
  static Future<void> logout() async {
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await apiClient.post(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (e) {
      print('[AuthApiService] Logout error: $e');
    } finally {
      // Clear tokens regardless of API response
      await tokenStorage.clearTokens();
    }
  }
}
