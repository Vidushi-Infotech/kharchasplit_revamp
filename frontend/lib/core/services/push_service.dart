import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'device_info_service.dart';

/// Top-level background handler. Firebase requires this to be a free
/// function (not a method) and registered via [FirebaseMessaging.onBackgroundMessage].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background message bodies are auto-displayed by FCM; we only need to be
  // here so the isolate can be spun up.
}

/// Handles FCM init, token registration with the backend, foreground display
/// via local notifications, and tap deep-link routing.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final StreamController<RemoteMessage> _tapController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _initialized = false;
  String? _currentToken;

  /// Stream of taps on a notification. Subscribe to route the user to the
  /// relevant screen based on `message.data['type']` etc.
  Stream<RemoteMessage> get onMessageTap => _tapController.stream;

  /// Stream of foreground push messages (fires whenever a push arrives
  /// while the app is in the foreground). Listen to this to refresh the
  /// in-app notifications inbox / badge in real time.
  Stream<RemoteMessage> get onForegroundMessage => _foregroundController.stream;

  String? get currentToken => _currentToken;

  /// One-time bootstrap. Call from `main()` after `Firebase.initializeApp()`.
  /// Idempotent — safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocalNotifications();

    // Request notification permissions (iOS prompt, Android 13+ runtime perm).
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // iOS-only: show heads-up notifications even when app is in foreground.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages: FCM does NOT auto-display these, so we route
    // them through flutter_local_notifications to get a system banner.
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App opened from a notification tap (background → foreground).
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_tapController.add);

    // App launched from a terminated state by a notification tap.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Defer one frame so router/listeners are wired up.
      scheduleMicrotask(() => _tapController.add(initialMessage));
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: (response) {
        // Convert tap-on-local-notif into a RemoteMessage-like event so
        // listeners can use the same handler.
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tapController.add(
            RemoteMessage(data: _parsePayload(payload)),
          );
        }
      },
    );
  }

  static Map<String, dynamic> _parsePayload(String payload) {
    // Expected format: "type=EXPENSE_ADDED;groupId=abc;expenseId=xyz"
    final out = <String, dynamic>{};
    for (final part in payload.split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      out[part.substring(0, eq)] = part.substring(eq + 1);
    }
    return out;
  }

  void _onForegroundMessage(RemoteMessage message) {
    // Always emit on the foreground stream so the inbox can refresh,
    // even for data-only (silent) messages.
    _foregroundController.add(message);

    final notif = message.notification;
    if (notif == null) return; // data-only message — nothing to display

    final payload = message.data.entries
        .map((e) => '${e.key}=${e.value}')
        .join(';');

    _local.show(
      id: notif.hashCode,
      title: notif.title,
      body: notif.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'General',
          channelDescription: 'KharchaSplit notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  /// Registers the current FCM token with the backend for [userId].
  /// Also wires a refresh listener so token rotation auto-re-registers.
  Future<void> registerWithBackend({
    required Dio dio,
    required String userId,
  }) async {
    if (!_initialized) await init();

    try {
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('[PushService] No FCM token yet');
        return;
      }
      _currentToken = token;
      await _postDevice(dio: dio, userId: userId, token: token);

      // Listen for token rotation and re-register.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        await _postDevice(dio: dio, userId: userId, token: newToken);
      });
    } catch (e) {
      debugPrint('[PushService] registerWithBackend failed: $e');
    }
  }

  Future<void> _postDevice({
    required Dio dio,
    required String userId,
    required String token,
  }) async {
    final device = await DeviceInfoService.describe();
    await dio.post(
      '/users/$userId/devices',
      data: {
        'fcmToken': token,
        'platform': device['platform'],
        'deviceName': device['name'],
        'osVersion': device['osVersion'],
        'appVersion': device['appVersion'],
      },
    );
  }

  /// Unregister this device's token from the backend (called on logout).
  /// Also deletes the local FCM token so a fresh one is minted on next login.
  Future<void> unregisterFromBackend({
    required Dio dio,
    required String userId,
  }) async {
    try {
      final token = _currentToken ?? await _fcm.getToken();
      if (token != null) {
        await dio.delete(
          '/users/$userId/devices',
          data: {'fcmToken': token},
        );
      }
      await _fcm.deleteToken();
      _currentToken = null;
    } catch (e) {
      debugPrint('[PushService] unregisterFromBackend failed: $e');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tapController.close();
    await _foregroundController.close();
  }

  /// True when the platform supports FCM (excludes desktop where not configured).
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
