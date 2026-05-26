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
///   SETTLEMENT_REMINDER  → { type, groupId }
///   GROUP_INVITE         → { type, groupId }
///   MEMBER_ADDED/LEFT/.. → { type, groupId }
///   EXPENSE_UPDATED/DEL  → { type, groupId, expenseId? }
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
      case 'SETTLEMENT_REMINDER':
      case 'GROUP_INVITE':
      case 'GROUP_ARCHIVED':
      case 'GROUP_COMPLETED':
      case 'MEMBER_ADDED':
      case 'MEMBER_LEFT':
      case 'MEMBER_REMOVED':
        if (groupId != null && groupId.isNotEmpty) {
          router.push('/home/groups/$groupId');
        }
        return;

      default:
        return;
    }
  }
}
