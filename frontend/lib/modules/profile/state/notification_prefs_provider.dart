import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/state/auth_provider.dart';

/// Notification preferences. The 9 fields with a corresponding backend
/// column (push/email, new_expense, group_invite, payment_received,
/// settlement_reminder, comment_mention, weekly_summary, product_updates)
/// are synced. `monthlySummary` and `tipsAndOffers` are UI-only for now
/// — they stay local until the backend grows columns for them.
class NotificationPrefs {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.newExpense = true,
    this.groupInvite = true,
    this.paymentReceived = true,
    this.settlementReminder = true,
    this.commentMention = true,
    this.weeklySummary = false,
    this.monthlySummary = false,
    this.productUpdates = false,
    this.tipsAndOffers = false,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool newExpense;
  final bool groupInvite;
  final bool paymentReceived;
  final bool settlementReminder;
  final bool commentMention;
  final bool weeklySummary;
  final bool monthlySummary;
  final bool productUpdates;
  final bool tipsAndOffers;

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? newExpense,
    bool? groupInvite,
    bool? paymentReceived,
    bool? settlementReminder,
    bool? commentMention,
    bool? weeklySummary,
    bool? monthlySummary,
    bool? productUpdates,
    bool? tipsAndOffers,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      newExpense: newExpense ?? this.newExpense,
      groupInvite: groupInvite ?? this.groupInvite,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      settlementReminder: settlementReminder ?? this.settlementReminder,
      commentMention: commentMention ?? this.commentMention,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      monthlySummary: monthlySummary ?? this.monthlySummary,
      productUpdates: productUpdates ?? this.productUpdates,
      tipsAndOffers: tipsAndOffers ?? this.tipsAndOffers,
    );
  }

  /// Parse the backend payload. Returns defaults for any missing keys.
  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    bool b(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return NotificationPrefs(
      pushEnabled: b('pushEnabled', true),
      emailEnabled: b('emailEnabled', false),
      newExpense: b('newExpense', true),
      groupInvite: b('groupInvite', true),
      paymentReceived: b('paymentReceived', true),
      settlementReminder: b('settlementReminder', true),
      commentMention: b('commentMention', true),
      weeklySummary: b('weeklySummary', false),
      productUpdates: b('productUpdates', false),
      // monthlySummary and tipsAndOffers are not on the backend yet —
      // keep the existing local value.
    );
  }

  /// Only the 9 server-known fields are serialised. The two UI-only
  /// toggles are intentionally excluded.
  Map<String, dynamic> toServerJson() => {
        'pushEnabled': pushEnabled,
        'emailEnabled': emailEnabled,
        'newExpense': newExpense,
        'groupInvite': groupInvite,
        'paymentReceived': paymentReceived,
        'settlementReminder': settlementReminder,
        'commentMention': commentMention,
        'weeklySummary': weeklySummary,
        'productUpdates': productUpdates,
      };
}

/// Backend-backed notification preferences.
/// - On user login, fetches prefs from `GET /users/:id/notification-prefs`.
/// - `update()` mutates local state optimistically, then PUTs the full
///   server-known payload. Failures roll back to the previous value.
/// - On logout, resets to defaults.
class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  Timer? _saveDebounce;
  NotificationPrefs? _serverSnapshot;

  @override
  NotificationPrefs build() {
    // Re-fetch whenever the signed-in user changes.
    ref.listen<AuthData>(authProvider, (prev, next) {
      if (prev?.user?.id != next.user?.id) {
        _serverSnapshot = null;
        if (next.user != null) {
          _loadFromBackend(next.user!.id);
        } else {
          state = const NotificationPrefs();
        }
      }
    });

    // Initial load if a user is already signed in when this provider is built.
    final initialUser = ref.read(authProvider).user;
    if (initialUser != null) {
      // Fire after build returns so we don't trigger a state set in build().
      Future.microtask(() => _loadFromBackend(initialUser.id));
    }

    return const NotificationPrefs();
  }

  Future<void> _loadFromBackend(String userId) async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      final res = await dio.get('/users/$userId/notification-prefs');
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      if (data is Map<String, dynamic>) {
        final loaded = NotificationPrefs.fromJson(data).copyWith(
          // Preserve UI-only toggles that aren't on the backend.
          monthlySummary: state.monthlySummary,
          tipsAndOffers: state.tipsAndOffers,
        );
        _serverSnapshot = loaded;
        state = loaded;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationPrefs] load failed: $e');
    }
  }

  /// Applies a mutator, updates local state immediately, and schedules a
  /// debounced PUT to the backend. Multiple rapid toggles coalesce into
  /// a single network call.
  void update(NotificationPrefs Function(NotificationPrefs) mutator) {
    final previous = state;
    final next = mutator(previous);
    if (identical(previous, next)) return;
    state = next;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      _pushToBackend(next, fallback: previous);
    });
  }

  Future<void> _pushToBackend(
    NotificationPrefs next, {
    required NotificationPrefs fallback,
  }) async {
    final user = ref.read(authProvider).user;
    if (user == null) return; // not signed in — keep local-only
    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.put(
        '/users/${user.id}/notification-prefs',
        data: next.toServerJson(),
      );
      _serverSnapshot = next;
    } catch (e) {
      // Roll back on failure so the UI matches the server.
      if (kDebugMode) debugPrint('[NotificationPrefs] save failed: $e');
      state = _serverSnapshot ?? fallback;
    }
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  NotificationPrefsNotifier.new,
);
