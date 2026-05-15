import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/push_service.dart';
import '../../auth/state/auth_provider.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: (json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{},
      isRead: json['isRead'] as bool? ?? false,
      readAt: _parseDate(json['readAt']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  NotificationItem copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    return null;
  }
}

class NotificationsInboxData {
  const NotificationsInboxData({
    this.items = const [],
    this.unreadCount = 0,
  });

  final List<NotificationItem> items;
  final int unreadCount;

  NotificationsInboxData copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
  }) {
    return NotificationsInboxData(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationsInboxNotifier
    extends AsyncNotifier<NotificationsInboxData> {
  StreamSubscription? _pushSub;

  @override
  Future<NotificationsInboxData> build() async {
    // Re-fetch the inbox whenever the signed-in user changes.
    ref.listen<AuthData>(authProvider, (prev, next) {
      if (prev?.user?.id != next.user?.id) {
        ref.invalidateSelf();
      }
    });

    // Live-update: whenever a foreground push arrives, refresh so the
    // badge and list update without the user needing to pull-to-refresh.
    _pushSub?.cancel();
    if (PushService.isSupportedPlatform) {
      _pushSub = PushService.instance.onForegroundMessage.listen((_) {
        // Small debounce-via-microtask so multiple bursts coalesce.
        Future.microtask(refresh);
      });
      ref.onDispose(() => _pushSub?.cancel());
    }

    final user = ref.read(authProvider).user;
    if (user == null) return const NotificationsInboxData();
    return _fetchAll(user.id);
  }

  Future<NotificationsInboxData> _fetchAll(String userId) async {
    final dio = ref.read(apiClientProvider).dio;
    final listRes = await dio.get('/users/$userId/notifications?limit=50');
    final rawList = (listRes.data is Map ? listRes.data['data'] : null);
    final items = rawList is List
        ? rawList
            .whereType<Map<String, dynamic>>()
            .map(NotificationItem.fromJson)
            .toList(growable: false)
        : <NotificationItem>[];

    final unread = items.where((n) => !n.isRead).length;
    return NotificationsInboxData(items: items, unreadCount: unread);
  }

  /// Refetch from the server (pull-to-refresh, post-push-arrival, etc.).
  Future<void> refresh() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAll(user.id));
  }

  /// Optimistically mark one notification as read. Rolls back on failure.
  Future<void> markRead(String notificationId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final current = state.value;
    if (current == null) return;

    final updated = current.items
        .map((n) => n.id == notificationId && !n.isRead
            ? n.copyWith(isRead: true, readAt: DateTime.now())
            : n)
        .toList(growable: false);
    final newUnread = updated.where((n) => !n.isRead).length;
    state = AsyncValue.data(
      current.copyWith(items: updated, unreadCount: newUnread),
    );

    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.patch(
        '/users/${user.id}/notifications/$notificationId/read',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Inbox] markRead failed: $e');
      state = AsyncValue.data(current); // rollback
    }
  }

  /// Mark every unread notification as read. Optimistic.
  Future<void> markAllRead() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final current = state.value;
    if (current == null || current.unreadCount == 0) return;

    final updated = current.items
        .map((n) => n.isRead
            ? n
            : n.copyWith(isRead: true, readAt: DateTime.now()))
        .toList(growable: false);
    state = AsyncValue.data(current.copyWith(items: updated, unreadCount: 0));

    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.patch('/users/${user.id}/notifications/read-all');
    } catch (e) {
      if (kDebugMode) debugPrint('[Inbox] markAllRead failed: $e');
      state = AsyncValue.data(current);
    }
  }
}

final notificationsInboxProvider = AsyncNotifierProvider<
    NotificationsInboxNotifier, NotificationsInboxData>(
  NotificationsInboxNotifier.new,
);

/// Lightweight derived provider for just the unread count — perfect for
/// driving the bell-icon badge without watching the full list.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final inbox = ref.watch(notificationsInboxProvider);
  return inbox.value?.unreadCount ?? 0;
});
