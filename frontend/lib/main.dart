import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'core/state/feature_flags_provider.dart';
import 'core/storage/local_store.dart';
import 'modules/outbox/state/outbox_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/banners/offline_banner.dart';
import 'core/services/app_logger.dart';
import 'core/services/notification_router.dart';
import 'core/services/push_service.dart';
import 'core/services/update_service.dart';
import 'core/state/connectivity_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/system_ui.dart';
import 'modules/notifications/state/push_refresh_provider.dart';

void main() async {
  // runZonedGuarded catches uncaught async errors that escape the framework.
  // Combined with the two onError hooks below, every unhandled exception
  // (sync widget build, async gap, isolate top-level) lands in Crashlytics.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Draw behind the status and navigation bars (Android), with both bars
    // transparent. Until the first frame picks the theme's style (see
    // _SystemBarsForTheme), follow the phone's light/dark setting.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      AppSystemUi.page(
        PlatformDispatcher.instance.platformBrightness == Brightness.dark,
      ),
    );

    // Firebase + push + Crashlytics. Wrapped so a missing config doesn't
    // crash app startup on platforms where we haven't set it up yet
    // (web / desktop).
    if (PushService.isSupportedPlatform) {
      try {
        await Firebase.initializeApp();

        // Crashlytics — collect unhandled Flutter framework errors and
        // platform-level errors. Disabled in debug to keep stack traces
        // local; Crashlytics dashboard would otherwise drown in dev noise.
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance
              .recordError(error, stack, fatal: true);
          return true;
        };

        // Only the background-handler *registration* belongs before
        // runApp — it's synchronous and cheap. The rest of push setup
        // (local-notification plugin, permission prompt, initial-message
        // lookup) is deferred until after the first frame; see
        // _KharchaSplitAppState.initState.
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
      } catch (e, st) {
        AppLogger.error('Firebase init failed',
            tag: 'main', error: e, stackTrace: st);
      }
    }

    // Offline cache + outbox (Hive). Never blocks startup on failure.
    await LocalStore.init();

    runApp(
      const ProviderScope(
        child: KharchaSplitApp(),
      ),
    );
  }, (error, stack) {
    // Final safety net — anything that escaped the framework's hooks.
    AppLogger.error('Uncaught zone error',
        tag: 'main', error: error, stackTrace: stack, fatal: true);
  });
}

/// Main app widget wrapped in Consumer to watch theme changes
class KharchaSplitApp extends ConsumerStatefulWidget {
  const KharchaSplitApp({Key? key}) : super(key: key);

  @override
  ConsumerState<KharchaSplitApp> createState() => _KharchaSplitAppState();
}

class _KharchaSplitAppState extends ConsumerState<KharchaSplitApp> {
  StreamSubscription? _notifTapSub;

  @override
  void initState() {
    super.initState();
    // Route notification taps to the appropriate screen via go_router.
    // Subscribed BEFORE PushService.init() runs so a cold-start tap
    // (getInitialMessage) is never emitted into an empty stream.
    if (PushService.isSupportedPlatform) {
      _notifTapSub = PushService.instance.onMessageTap.listen((message) {
        NotificationRouter.handleTap(appRouter, message);
      });
    }
    // Refetch balances / groups when a relevant push lands in the foreground.
    ref.read(pushRefreshProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Push setup runs after the first frame. Doing it in main() blocked
      // the very first paint behind the Android 13+ / iOS notification
      // permission dialog, so the app looked frozen on launch. Failures are
      // logged and ignored — push is not required for the app to work.
      if (PushService.isSupportedPlatform) {
        unawaited(PushService.instance.init().catchError((e, st) {
          AppLogger.error('Push init failed',
              tag: 'main', error: e, stackTrace: st);
        }));
      }
      // Kick off the in-app update check once the first frame is rendered
      // so the navigator key is attached and dialogs can be shown. Failures
      // are swallowed inside the service — version gating is best-effort.
      ref.read(updateServiceProvider).checkForUpdate(
            navigatorKey: appRouter.routerDelegate.navigatorKey,
          );
    });
  }

  @override
  void dispose() {
    _notifTapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    // Kick the connectivity service awake — service starts listening on
    // first read and survives for the app's lifetime via ref.onDispose.
    ref.watch(connectivityServiceProvider);
    // Load server feature flags at start-up, so flag checks inside tap
    // handlers (watchFeature in a callback) don't read "still loading" as off.
    ref.listen(featureFlagsProvider, (_, _) {});
    // Offline outbox: loads queued changes and sends them when possible.
    ref.listen(outboxProvider, (_, _) {});

    return MaterialApp.router(
      title: 'Kharcha Split',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      // The banner overlays every route by wrapping the router's content.
      builder: (context, child) => _SystemBarsForTheme(
        child: _NonNegativeInsets(
          child: OfflineBanner(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Default status / navigation bar style for every screen, from the app's
/// theme (not the phone's): pages without their own app bar, the tab
/// roots and sheets get readable icons. App bars, the teal banners and the
/// always-dark screens set their own, which take precedence.
class _SystemBarsForTheme extends StatelessWidget {
  const _SystemBarsForTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(isDark),
      child: child,
    );
  }
}

/// iOS 26 briefly reports a negative keyboard inset while the keyboard
/// animates; any padding built from it then fails Flutter's
/// non-negative assertion. Clamp the insets once for every route and sheet.
class _NonNegativeInsets extends StatelessWidget {
  const _NonNegativeInsets({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final v = mq.viewInsets;
    // Always the same widget shape, so the app's state is never rebuilt
    // when the insets flip sign.
    return MediaQuery(
      data: v.isNonNegative
          ? mq
          : mq.copyWith(
              viewInsets: EdgeInsets.fromLTRB(
                v.left < 0 ? 0 : v.left,
                v.top < 0 ? 0 : v.top,
                v.right < 0 ? 0 : v.right,
                v.bottom < 0 ? 0 : v.bottom,
              ),
            ),
      child: child,
    );
  }
}

/// Lets a mouse drag scroll the page, which Flutter disables by default
/// outside of touch. Without it, click-and-drag on a desktop browser does
/// nothing — trackpad and wheel scrolling work either way.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
