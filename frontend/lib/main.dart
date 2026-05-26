import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/banners/offline_banner.dart';
import 'core/services/app_logger.dart';
import 'core/services/notification_router.dart';
import 'core/services/push_service.dart';
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

        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
        await PushService.instance.init();
      } catch (e, st) {
        AppLogger.error('Firebase / push init failed',
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
    if (PushService.isSupportedPlatform) {
      _notifTapSub = PushService.instance.onMessageTap.listen((message) {
        NotificationRouter.handleTap(appRouter, message);
      });
    }
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
      // The banner overlays every route by wrapping the router's content.
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
