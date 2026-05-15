import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_router.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Status bar: transparent background with DARK icons/text across all screens
  // so the system clock/battery read against the app's light backgrounds.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android: dark icons
      statusBarBrightness: Brightness.light, // iOS: light bg → dark content
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase + push notifications. Wrapped so a missing config doesn't
  // crash app startup on platforms where we haven't set it up yet (web/desktop).
  if (PushService.isSupportedPlatform) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushService.instance.init();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[main] Firebase init failed: $e');
      }
    }
  }

  runApp(
    const ProviderScope(
      child: KharchaSplitApp(),
    ),
  );
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
    );
  }
}
