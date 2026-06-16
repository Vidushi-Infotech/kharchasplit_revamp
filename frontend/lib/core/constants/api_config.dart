

/// Backend API configuration.
///
/// Default points at production (`api.kharchasplit.com`). For local dev,
/// override at build/run time, e.g.:
///
///     flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
///
/// On Android emulator the host laptop is reachable as `10.0.2.2`; on a
/// physical device, use `adb reverse tcp:3000 tcp:3000` so `localhost:3000`
/// from the phone hits the dev host.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // ─── Production (default) ───
    defaultValue: 'https://api.kharchasplit.com/api/v1',
    // ─── Local dev toggle ───
    // To run against a backend on your laptop, comment the production
    // line above and uncomment ONE of the lines below. Replace the LAN
    // IP with your own Mac's `ipconfig getifaddr en0`. The backend must
    // listen on 0.0.0.0 (not just 127.0.0.1) for the phone to reach it,
    // and `usesCleartextTraffic` is already allowed in the debug
    // Android manifest so plain `http://` works.
    //
    // defaultValue: 'http://192.168.X.X:3000/api/v1',   // your Mac LAN IP
    // defaultValue: 'http://10.0.2.2:3000/api/v1',      // Android emulator → host
    // defaultValue: 'http://localhost:3000/api/v1',     // physical device + `adb reverse tcp:3000 tcp:3000`
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String currentUserKey = 'current_user';

  /// SHA-256 fingerprints (hex, lowercase, colon-free) of certs we trust
  /// for the production API. The interceptor in [ApiClient] only enforces
  /// pinning when this list is non-empty AND the URL is HTTPS — local dev
  /// over `http://localhost` is therefore unaffected.
  ///
  /// Pin BOTH the current leaf cert AND a backup (intermediate or future
  /// renewed leaf) so cert rotation never bricks the app.
  ///
  /// Extract a fingerprint with:
  ///   openssl s_client -servername api.kharchasplit.com -connect api.kharchasplit.com:443 \
  ///     </dev/null 2>/dev/null \
  ///     | openssl x509 -fingerprint -sha256 -noout \
  ///     | sed 's/SHA256 Fingerprint=//;s/://g' \
  ///     | tr 'A-Z' 'a-z'
  static const List<String> certPinSha256 = <String>[
    // 'aabbcc...primary leaf cert sha256...',
    // 'ddeeff...backup intermediate sha256...',
  ];
}
