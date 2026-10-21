import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

/// Routes a tapped FCM notification to the relevant screen.
/// The backend includes a `type` plus context IDs in the `data` payload —
/// we map those to go_router routes here.
///
/// Expected payload shapes:
///   EXPENSE_ADDED        → { type, groupId, expenseId }
///   SETTLEMENT_CREATED   → { type, groupId, settlementId }
///   SETTLEMENT_CONFIRMED → { type, groupId, settlementId }
///   SETTLEMENT_DELETED   → { type, groupId, settlementId }
///   SETTLEMENT_REMINDER  → { type, groupId }
///   GROUP_INVITE         → { type, groupId }
///   MEMBER_ADDED/LEFT/.. → { type, groupId }
///   EXPENSE_UPDATED/DEL  → { type, groupId, expenseId? }
///   EXPENSE_COMMENT      → { type, groupId, expenseId }  (→ the expense)
///   GROUP_DELETED        → { type, groupId }  (group is gone → groups list)
///   REMOVED_FROM_GROUP   → { type, groupId }  (no access any more → groups list)
///   BALANCE_WRITTEN_OFF  → { type, groupId }
///   NEW_LOGIN / PASSWORD_CHANGED / SESSIONS_REVOKED → { type }  (→ Security)
///   UPI_ID_REQUESTED     → { type, requesterId, requesterName, amount }
///                          (→ Edit profile, where the UPI ID is added)
///   PAYMENT_NOT_RECEIVED → { type, groupId }  (receiver rejected a payment)
///   SETTLE_ALL_RECEIVED  → { type, batchId }  (spans groups → Friends tab)
class NotificationRouter {
  NotificationRouter._();

  /// Handle a tap on a system push notification.
  static void handleTap(GoRouter router, RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == null) return;
    routeByType(router, type, message.data);
  }

  /// Handle a tap on an in-app inbox row. The inbox stores `data` as JSON
  /// where values may be non-strings — we coerce on lookup.
  static void routeByType(
    GoRouter router,
    String type,
    Map<String, dynamic> data,
  ) {
    final groupId = data['groupId']?.toString();
    final expenseId = data['expenseId']?.toString();

    switch (type) {
      case 'EXPENSE_ADDED':
      case 'EXPENSE_UPDATED':
      case 'EXPENSE_COMMENT':
        if (expenseId != null && expenseId.isNotEmpty) {
          router.push('/expense/$expenseId');
          return;
        }
        if (groupId != null && groupId.isNotEmpty) {
          router.push('/home/groups/$groupId');
        }
        return;

      case 'EXPENSE_DELETED':
      case 'SETTLEMENT_CREATED':
      case 'SETTLEMENT_CONFIRMED':
      case 'SETTLEMENT_DELETED':
      case 'SETTLEMENT_REMINDER':
      case 'BALANCE_WRITTEN_OFF':
      case 'GROUP_INVITE':
      case 'GROUP_ARCHIVED':
      case 'GROUP_COMPLETED':
      case 'MEMBER_ADDED':
      case 'MEMBER_LEFT':
      case 'MEMBER_REMOVED':
      case 'PAYMENT_NOT_RECEIVED':
        if (groupId != null && groupId.isNotEmpty) {
          router.push('/home/groups/$groupId');
        }
        return;

      case 'GROUP_DELETED':
      case 'REMOVED_FROM_GROUP':
        router.push('/home/groups');
        return;

      case 'UPI_ID_REQUESTED':
        router.push('/home/profile/edit');
        return;

      case 'SETTLE_ALL_RECEIVED':
        router.push('/home/friends');
        return;

      case 'NEW_LOGIN':
      case 'PASSWORD_CHANGED':
      case 'SESSIONS_REVOKED':
        router.push('/home/profile/security');
        return;

      default:
        return;
    }
  }
}
