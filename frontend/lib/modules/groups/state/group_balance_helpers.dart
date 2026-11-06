import '../../../models/group_model.dart';
import 'group_detail_provider.dart';

/// Raw pairwise debts from [myId]'s perspective, ignoring "Simplify group
/// debts". Delegates to the shared [computePairwiseDebts]. Only for what
/// the server also checks raw (removing a member); balances shown to the
/// user come from [groupVisibleDebts].
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

/// The debts [myId] sees in the group, same sign as [computePairwiseDebts]
/// (> 0 = I owe them). In a group with "Simplify group debts" on these are
/// the server's simplified transfers (whatever the feature flag says), so
/// the Balances tab, Settle up amounts and Remind match the server;
/// otherwise the raw pairwise debts.
Map<String, double> groupVisibleDebts({
  required String myId,
  required GroupDetail detail,
}) {
  if (!detail.group.simplifyDebts) {
    return groupPairwiseDebts(myId: myId, detail: detail);
  }
  return simplifiedPairDebts(
    myId: myId,
    transfers: detail.group.simplifiedTransfers,
  );
}

/// [myId]'s per-person map from simplified [transfers]: from = me → I owe
/// `to`; to = me → `from` owes me.
Map<String, double> simplifiedPairDebts({
  required String myId,
  required List<SimplifiedTransfer> transfers,
}) {
  final pair = <String, double>{};
  for (final t in transfers) {
    if (t.fromUserId == myId) {
      pair[t.toUserId] = (pair[t.toUserId] ?? 0) + t.amount;
    } else if (t.toUserId == myId) {
      pair[t.fromUserId] = (pair[t.fromUserId] ?? 0) - t.amount;
    }
  }
  return pair;
}
