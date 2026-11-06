import 'package:flutter/foundation.dart';

/// Holds a deep link that arrived before the app finished booting, so the
/// splash screen can hand the user back to it once auth is resolved.
///
/// Only ever active on the web. On mobile the app is always entered through
/// the launcher at `/`, so there is nothing to preserve and
/// [captureIfColdStart] returns null for every call — the redirect it powers
/// is a no-op on touch platforms by construction.
class WebDeepLink {
  const WebDeepLink._();

  static bool _booted = false;
  static String? _pending;

  /// Routes that never require a signed-in user.
  static const _publicPrefixes = <String>[
    '/onboarding',
    '/login',
    '/register',
    '/forgot-password',
    '/profile-setup',
  ];

  static bool isPublic(String location) =>
      location == '/' || _publicPrefixes.any((p) => location.startsWith(p));

  /// Called from the router's redirect.
  ///
  /// Returns `/` when [location] is a protected route reached on a cold web
  /// load — the target is stashed and the splash flow takes over. Returns null
  /// in every other case, including every navigation once the app has booted,
  /// so in-app routing is untouched.
  static String? captureIfColdStart(String location) {
    if (!kIsWeb || _booted) return null;
    if (isPublic(location)) {
      _booted = true;
      return null;
    }
    _pending = location;
    return '/';
  }

  /// Consumes the stashed destination, if any. Marks the app as booted so the
  /// redirect above goes inert for the rest of the session.
  static String? take() {
    _booted = true;
    final target = _pending;
    _pending = null;
    return target;
  }

  /// Marks boot complete without consuming a destination — used when the user
  /// turns out to be signed out and is being sent to onboarding or login.
  static void discard() {
    _booted = true;
    _pending = null;
  }

  @visibleForTesting
  static void resetForTest() {
    _booted = false;
    _pending = null;
  }
}
