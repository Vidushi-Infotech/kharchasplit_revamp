import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../services/connectivity_service.dart';
import '../services/token_storage.dart';
import 'outbox_item.dart';
import 'outbox_rules.dart';
import 'outbox_store.dart';

/// Marks a request sent by the outbox itself (never queued again).
const outboxReplayExtra = 'outboxReplay';

/// Puts expense / payment writes in the outbox instead of failing them when
/// there's no connection ([OutboxRules.kindFor]), and answers the app as if
/// the server had (`queued: true` in the body), so the add / edit / delete
/// screens close as usual. The outbox notifier sends them later.
///
/// [OutboxInterceptor] goes near the front: requests while known offline,
/// and any edit/delete of an expense that only exists in the outbox
/// ("local-…" id — merged into the queued create, never sent).
/// [OutboxFallbackInterceptor] goes last: a write that failed for lack of a
/// connection after the retries. Its Idempotency-Key is kept, so if the
/// first attempt did reach the server the replay returns that result.
class OutboxInterceptor extends Interceptor {
  OutboxInterceptor(this._tokens, this._connectivity);

  final TokenStorage _tokens;
  final ConnectivityService _connectivity;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[outboxReplayExtra] != true && OutboxStore.available) {
      final kind = OutboxRules.kindFor(options.method, options.path);
      final local = OutboxRules.isLocalId(OutboxRules.expenseIdOf(options.path));
      if (kind != null &&
          (local || _connectivity.current == ConnectivityState.offline)) {
        final res = await queueRequest(options, kind, _tokens);
        if (res != null) return handler.resolve(res);
      }
    }
    handler.next(options);
  }
}

class OutboxFallbackInterceptor extends Interceptor {
  OutboxFallbackInterceptor(this._tokens);

  final TokenStorage _tokens;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isConnectivity = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout;
    final kind = OutboxRules.kindFor(options.method, options.path);
    if (isConnectivity &&
        kind != null &&
        options.extra[outboxReplayExtra] != true &&
        OutboxStore.available) {
      final res = await queueRequest(options, kind, _tokens);
      if (res != null) return handler.resolve(res);
    }
    handler.next(err);
  }
}

/// Queue [options] (merging with the outbox) and build the app's answer.
/// Null when it can't be queued (no signed-in user).
Future<Response<dynamic>?> queueRequest(
  RequestOptions options,
  OutboxKind kind,
  TokenStorage tokens,
) async {
  final user = await tokens.readUser();
  final userId = (user?['id'] ?? user?['userId']) as String?;
  if (userId == null) return null;

  final data = options.data is Map
      ? (options.data as Map).cast<String, dynamic>()
      : null;
  final trimmed = OutboxRules.trimBody(data);
  final expenseId = OutboxRules.expenseIdOf(options.path);
  // Keep a key the request already had (a retried create), else a new one.
  final key = options.headers['Idempotency-Key'] as String? ?? const Uuid().v4();
  final item = OutboxItem(
    id: key,
    userId: userId,
    kind: kind,
    method: options.method.toUpperCase(),
    path: options.path,
    body: trimmed.body,
    groupId: (data?['groupId'] as String?) ??
        (options.queryParameters['groupId'] as String?) ??
        _groupOfQueued(userId, expenseId),
    expenseId: expenseId,
    createdAt: DateTime.now(),
    receiptDropped: trimmed.receiptDropped,
  );
  await OutboxStore.saveAll(userId, OutboxRules.enqueue(OutboxStore.itemsFor(userId), item));
  OutboxStore.announceQueued(item);

  final created = kind == OutboxKind.createExpense || kind == OutboxKind.createSettlement;
  return Response(
    requestOptions: options,
    statusCode: created ? 201 : 200,
    data: OutboxRules.syntheticResponse(item),
    extra: {'queued': true},
  );
}

/// The group of an expense created offline (edits of it carry no groupId).
String? _groupOfQueued(String userId, String? expenseId) {
  if (!OutboxRules.isLocalId(expenseId)) return null;
  final createId = OutboxRules.itemIdOfLocal(expenseId!);
  for (final i in OutboxStore.itemsFor(userId)) {
    if (i.id == createId) return i.groupId;
  }
  return null;
}
