/// Settle up / Remind rules for the per-person rows on the expense detail
/// screen. Both read the OUTSTANDING net with each person in the group
/// (`groupVisibleDebts`: > 0 ⇒ I owe them, < 0 ⇒ they owe me), not this one
/// expense's share, so the buttons disappear once settled.
library;

import '../../../models/expense_model.dart';

/// What's left to settle with [userId] after my already-pending payments to
/// them; 0 when I don't owe them anything.
double remainingToSettle({
  required String userId,
  required Map<String, double> netByUserId,
  required Map<String, double> pendingOutByUserId,
}) {
  final net = netByUserId[userId] ?? 0;
  // Guard the clamp: clamp(0, negative) would throw.
  if (net <= 0) return 0;
  return (net - (pendingOutByUserId[userId] ?? 0)).clamp(0, net).toDouble();
}

/// Whether I can remind [userId] from this expense: I paid for it (any
/// payer), they're someone else and they still net-owe me.
bool canRemindOnExpense({
  required String? myId,
  required String userId,
  required Set<String> payerIds,
  required Map<String, double> netByUserId,
}) {
  if (myId == null || userId == myId) return false;
  if (!payerIds.contains(myId)) return false;
  return (netByUserId[userId] ?? 0) < -0.01;
}

/// My net on one expense: what I paid minus my share (> 0 ⇒ others owe me,
/// < 0 ⇒ I owe). Payer-aware — someone who paid part of a multi-payer
/// expense but less than their share still owes.
double myNetOnExpense(ExpenseModel expense, String myId) {
  final share = expense.splits
      .where((s) => s.userId == myId)
      .fold<double>(0, (t, s) => t + s.owedShare);
  return expense.paidByUser(myId) - share;
}
