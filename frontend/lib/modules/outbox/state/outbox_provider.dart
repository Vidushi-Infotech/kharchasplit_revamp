import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/outbox/outbox_interceptor.dart';
import '../../../core/outbox/outbox_item.dart';
import '../../../core/outbox/outbox_rules.dart';
import '../../../core/outbox/outbox_store.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/state/connectivity_provider.dart';
import '../../auth/state/auth_provider.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../expenses/state/expense_detail_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';

/// The signed-in user's unsent changes (oldest first), and the sender.
///
/// Sends sequentially, oldest first: when the app starts, when the
/// connection returns, when the app is resumed, every 30 s while there's
/// something pending, and on demand ("Sync now" / Retry). A connection
/// problem or 5xx stops the run (tried again later); a 4xx marks just that
/// change as failed with the reason, and the rest carry on.
final outboxProvider =
    NotifierProvider<OutboxNotifier, List<OutboxItem>>(OutboxNotifier.new);

/// Number of changes not on the server yet (pending + failed).
final unsyncedCountProvider = Provider<int>((ref) => ref.watch(outboxProvider).length);

class OutboxNotifier extends Notifier<List<OutboxItem>> {
  bool _draining = false;

  String? get _userId => ref.read(authProvider).user?.id;

  @override
  List<OutboxItem> build() {
    final userId = ref.watch(authProvider.select((s) => s.user?.id));
    final changes = OutboxStore.changes.listen((_) => _reload(userId));
    final conn = ref.read(connectivityServiceProvider).stream.listen((s) {
      if (s != ConnectivityState.online) return;
      // Back online: send what's queued and replace the cached data on
      // screen with fresh data.
      unawaited(drain());
      ref.invalidate(groupsProvider);
      ref.invalidate(dashboardProvider);
    });
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.any((i) => !i.isFailed)) unawaited(drain());
    });
    final life = AppLifecycleListener(onResume: () => unawaited(drain()));
    ref.onDispose(() {
      changes.cancel();
      conn.cancel();
      timer.cancel();
      life.dispose();
    });
    Future.microtask(drain);
    return OutboxStore.itemsFor(userId);
  }

  void _reload(String? userId) {
    final before = state;
    final after = OutboxStore.itemsFor(userId);
    state = after;
    // Groups whose shown expenses change (an item added, sent or failed).
    for (final g in {...before, ...after}.map((i) => i.groupId).whereType<String>()) {
      ref.invalidate(groupDetailProvider(g));
    }
  }

  /// Send what's pending. Safe to call any time; one run at a time.
  Future<void> drain() async {
    final userId = _userId;
    if (_draining || userId == null) return;
    _draining = true;
    try {
      final dio = ref.read(apiClientProvider).dio;
      for (final item in OutboxStore.itemsFor(userId)) {
        if (item.isFailed) continue;
        final outcome = await _send(dio, item);
        if (outcome.isDone) {
          await OutboxStore.remove(item.id);
          _refreshAfter(item);
        } else if (outcome.isRetry) {
          await OutboxStore.put(item.copyWith(attempts: item.attempts + 1));
          break;
        } else {
          await OutboxStore.put(item.copyWith(
            status: OutboxStatus.failed,
            attempts: item.attempts + 1,
            error: failureText(outcome),
            errorCode: outcome.code,
          ));
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<SendOutcome> _send(Dio dio, OutboxItem item) async {
    try {
      final res = await dio.request<dynamic>(
        item.path,
        data: item.body,
        options: Options(
          method: item.method,
          headers: {if (item.method == 'POST') 'Idempotency-Key': item.id},
          extra: {outboxReplayExtra: true},
        ),
      );
      return OutboxRules.classify(item: item, status: res.statusCode, body: res.data);
    } on DioException catch (e) {
      final conn = e.type != DioExceptionType.badResponse;
      return OutboxRules.classify(
        item: item,
        status: e.response?.statusCode,
        body: e.response?.data,
        connectivityError: conn,
      );
    }
  }

  void _refreshAfter(OutboxItem item) {
    ref.invalidate(groupsProvider);
    ref.invalidate(dashboardProvider);
    if (item.groupId != null) ref.invalidate(groupDetailProvider(item.groupId!));
    final id = item.expenseId;
    if (id != null && !OutboxRules.isLocalId(id)) ref.invalidate(expenseDetailProvider(id));
  }

  /// Failed → pending, then send.
  Future<void> retry(String id) async {
    final item = state.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    await OutboxStore.put(item.copyWith(status: OutboxStatus.pending, clearError: true));
    await drain();
  }

  Future<void> discard(String id) => OutboxStore.remove(id);
}

/// User-facing reason for a change the server refused.
String failureText(SendOutcome o) {
  switch (o.code) {
    case 'EDIT_CONFLICT':
      return AppStrings.syncConflict;
    case 'EXPENSE_DELETED':
      return AppStrings.syncExpenseDeleted;
    case 'GROUP_ARCHIVED':
      return AppStrings.syncGroupArchived;
  }
  if (o.message == 'User is not a member of this group') return AppStrings.syncNotMember;
  return o.message ?? 'The server refused this change';
}
