/// One change made offline (or whose request failed for lack of a
/// connection), waiting in the outbox to be sent. See [OutboxRules] for how
/// items are created, merged and judged, and the outbox notifier
/// (modules/outbox) for sending them.
enum OutboxKind { createExpense, updateExpense, deleteExpense, createSettlement }

enum OutboxStatus { pending, failed }

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.userId,
    required this.kind,
    required this.method,
    required this.path,
    this.body,
    this.groupId,
    this.expenseId,
    required this.createdAt,
    this.attempts = 0,
    this.status = OutboxStatus.pending,
    this.error,
    this.errorCode,
    this.receiptDropped = false,
  });

  /// uuid v4 — also the Idempotency-Key, so a replay never duplicates.
  final String id;

  /// Only the signed-in user's items are shown and sent.
  final String userId;
  final OutboxKind kind;
  final String method;
  final String path;

  /// The exact JSON the repository sent.
  final Map<String, dynamic>? body;
  final String? groupId;

  /// The server expense an update/delete targets.
  final String? expenseId;
  final DateTime createdAt;
  final int attempts;
  final OutboxStatus status;

  /// Why it failed (shown to the user) and the server's error code.
  final String? error;
  final String? errorCode;

  /// The receipt photo was too big to keep offline and was left out.
  final bool receiptDropped;

  /// Id the app uses for an expense / payment created offline until the
  /// server assigns one.
  String get localId => 'local-$id';

  bool get isFailed => status == OutboxStatus.failed;

  OutboxItem copyWith({
    Map<String, dynamic>? body,
    int? attempts,
    OutboxStatus? status,
    String? error,
    String? errorCode,
    bool clearError = false,
  }) =>
      OutboxItem(
        id: id,
        userId: userId,
        kind: kind,
        method: method,
        path: path,
        body: body ?? this.body,
        groupId: groupId,
        expenseId: expenseId,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        receiptDropped: receiptDropped,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'kind': kind.name,
        'method': method,
        'path': path,
        'body': body,
        'groupId': groupId,
        'expenseId': expenseId,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'status': status.name,
        'error': error,
        'errorCode': errorCode,
        'receiptDropped': receiptDropped,
      };

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
        id: j['id'] as String,
        userId: j['userId'] as String,
        kind: OutboxKind.values.byName(j['kind'] as String),
        method: j['method'] as String,
        path: j['path'] as String,
        body: (j['body'] as Map?)?.cast<String, dynamic>(),
        groupId: j['groupId'] as String?,
        expenseId: j['expenseId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        status: OutboxStatus.values.byName(j['status'] as String? ?? 'pending'),
        error: j['error'] as String?,
        errorCode: j['errorCode'] as String?,
        receiptDropped: j['receiptDropped'] == true,
      );
}
