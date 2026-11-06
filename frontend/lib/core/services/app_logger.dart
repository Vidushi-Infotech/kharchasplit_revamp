import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Single logging surface for the app.
///
/// In debug builds: routes through `dart:developer.log` so messages appear in
/// the IDE console with proper level / timestamp.
/// In release builds: drops `debug`/`info` chatter, sends `warn` as a
/// breadcrumb to Crashlytics, and reports `error` as a non-fatal event.
///
/// Why a wrapper? Two things:
///   1. We never want a raw `print()` in production code paths — they leak
///      to logcat and never reach our crash reporter.
///   2. If we ever swap Crashlytics for Sentry / Datadog, only this file
///      changes.
class AppLogger {
  AppLogger._();

  /// Verbose tracing — completely silenced in release builds.
  static void debug(String message, {String? tag}) {
    if (!kDebugMode) return;
    developer.log(message, name: tag ?? 'app', level: 500);
  }

  /// Routine state-change logs. Silenced in release.
  static void info(String message, {String? tag}) {
    if (!kDebugMode) return;
    developer.log(message, name: tag ?? 'app', level: 800);
  }

  /// Something unexpected happened but the user can keep going. Recorded as
  /// a Crashlytics breadcrumb in release so it shows up alongside the next
  /// crash from the same user.
  static void warn(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final fullTag = tag ?? 'app';
    if (kDebugMode) {
      developer.log(message,
          name: fullTag, error: error, stackTrace: stackTrace, level: 900);
    } else {
      // Crashlytics only — silent in console.
      try {
        FirebaseCrashlytics.instance.log('[$fullTag] $message');
      } catch (_) {/* Crashlytics not initialised — swallow. */}
    }
  }

  /// Caught exception that should land in the crash reporter as a
  /// **non-fatal**. Use for repository / network / parse failures the user
  /// shouldn't see crash, but we want telemetry on.
  static void error(
    String message, {
    String? tag,
    required Object error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    final fullTag = tag ?? 'app';
    if (kDebugMode) {
      developer.log('ERROR: $message',
          name: fullTag, error: error, stackTrace: stackTrace, level: 1000);
      return;
    }
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: '[$fullTag] $message',
        fatal: fatal,
      );
    } catch (_) {/* Crashlytics not initialised — swallow. */}
  }
}
