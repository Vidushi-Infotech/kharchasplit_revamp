import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
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

void main() async {
  // runZonedGuarded catches uncaught async errors that escape the framework.
  // Combined with the two onError hooks below, every unhandled exception
  // (sync widget build, async gap, isolate top-level) lands in Crashlytics.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
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
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox.shrink()),
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
