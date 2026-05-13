/// Backend API configuration.
///
/// On Android, requests are routed through `adb reverse tcp:3000 tcp:3000`,
/// so `localhost:3000` on the phone hits the dev host.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String currentUserKey = 'current_user';
}
