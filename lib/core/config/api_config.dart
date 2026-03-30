/// API Configuration
/// Comment/uncomment to switch between local development and production

// ============================================
// LOCAL DEVELOPMENT
// ============================================
// const String apiBaseUrl = 'http://192.168.8.117:3000/api/v1';

// ============================================
// PRODUCTION
// ============================================
const String apiBaseUrl = 'https://api.kharchasplit.com/api/v1';

// ============================================

const Duration apiTimeout = Duration(seconds: 30);

final class ApiConfig {
  static const String baseUrl = apiBaseUrl;
  static const Duration timeout = apiTimeout;
  static const String contentType = 'application/json';
}
