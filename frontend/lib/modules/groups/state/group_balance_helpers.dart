import 'package:collection/collection.dart';
import '../widgets/balance_summary_cards.dart';
import 'group_detail_provider.dart';

/// Pairwise debts from the current user's perspective. Delegates to the
/// shared [computePairwiseDebts] so the screen, the log rows and the
/// expense-detail buttons all agree (and match the backend, which counts
/// only confirmed settlements).
Map<String, double> groupPairwiseDebts({
  required String myId,
  required GroupDetail detail,
}) {
  return computePairwiseDebts(
    myId: myId,
    expenses: detail.expenses,
    settlements: detail.settlements,
  );
}

/// Per-person net balances vs. the current user, sorted by magnitude
/// (largest first) for the balance cards carousel.
List<BalanceCardData> buildBalanceCardData({
  required String myId,
  required GroupDetail detail,
  Map<String, double> pendingOut = const {},
}) {
  final pair = groupPairwiseDebts(myId: myId, detail: detail);
  final cards = <BalanceCardData>[];

  // "You" card first — my net across the group (positive = I'm owed).
  final me = detail.members.firstWhereOrNull((m) => m.id == myId);
  if (me != null) {
    final sumIOwe = pair.values.fold<double>(0, (s, v) => s + v);
    final myNet = -sumIOwe; // >0 ⇒ others owe me overall
    cards.add(
      BalanceCardData(
        member: me,
        amount: myNet.abs(),
        iOweThem: myNet < 0,
        isMe: true,
        settled: myNet.abs() <= 0.01,
      ),
    );
  }

  // Every other member — including those who are settled up.
  final others = <BalanceCardData>[];
  for (final m in detail.members) {
    if (m.id == myId) continue;
    final v = pair[m.id] ?? 0;
    final iOwe = v > 0;
    // Only my outgoing pending matters for Settle Up.
    final pend = iOwe ? (pendingOut[m.id] ?? 0).clamp(0, v).toDouble() : 0.0;
    final settle = iOwe ? (v - pend).clamp(0, v).toDouble() : 0.0;
    others.add(
      BalanceCardData(
        member: m,
        amount: v.abs(),
        iOweThem: iOwe,
        settled: v.abs() <= 0.01,
        settleAmount: settle,
        pendingAmount: pend,
      ),
    );
  }
  // Outstanding balances first (largest first), settled members last.
  others.sort((a, b) {
    if (a.settled != b.settled) return a.settled ? 1 : -1;
    return b.amount.compareTo(a.amount);
  });

  cards.addAll(others);
  return cards;
}
