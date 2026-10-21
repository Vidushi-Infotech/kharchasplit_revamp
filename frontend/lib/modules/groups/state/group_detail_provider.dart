import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/outbox/outbox_store.dart';
import '../../../core/state/keep_alive_for.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/expense_model.dart';
import '../../../models/group_model.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../outbox/state/outbox_overlay.dart';

class GroupDetail {
  const GroupDetail({
    required this.group,
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.totalExpense,
  });

  final GroupModel group;
  final List<UserModel> members;
  final List<ExpenseModel> expenses;
  final List<SettlementModel> settlements;
  final double totalExpense;
}

/// Cached for a few minutes after the screen is closed, then released.
/// A process-lifetime cache here retained every visited group's full
/// expense list (receipts included) until the app died.
final groupDetailProvider =
    FutureProvider.autoDispose.family<GroupDetail, String>((
  ref,
  groupId,
) async {
  keepAliveFor(ref, const Duration(minutes: 5));
  final groupsRepo = ref.read(groupsRepositoryProvider);
  final expensesRepo = ref.read(expensesRepositoryProvider);
  final settlementsRepo = ref.read(settlementsRepositoryProvider);

  // Fetch group + expenses + settlements in parallel. Pairwise balances are
  // computed client-side (computePairwiseDebts), so we need EVERY expense
  // and settlement — a single page would silently produce wrong totals.
  final results = await Future.wait([
    groupsRepo.getById(groupId),
    expensesRepo.listAllForGroup(groupId),
    settlementsRepo.listAllForGroup(groupId),
  ]);

  final group = results[0] as GroupModel;
  // With this user's unsent offline changes applied (marked pending); the
  // outbox refreshes this provider whenever those change.
  final withOutbox = applyOutbox(
    groupId: groupId,
    expenses: results[1] as List<ExpenseModel>,
    settlements: results[2] as List<SettlementModel>,
    items: OutboxStore.itemsFor(ref.read(authProvider).user?.id),
  );
  final expenses = withOutbox.expenses;
  final settlements = withOutbox.settlements;

  final totalExpense = expenses.fold<double>(0, (s, e) => s + e.amount);

  return GroupDetail(
    group: group,
    members: group.members,
    expenses: expenses,
    settlements: settlements,
    totalExpense: totalExpense,
  );
});

/// Net pairwise balance between [myId] and every other person, from myId's
/// perspective:
///   pair[otherId] > 0  → I owe them that much
///   pair[otherId] < 0  → they owe me |that much|
///   pair[otherId] ~ 0  → settled
///
/// Same rules as the backend ledger (services/ledger.js): only settlements
/// the server marked 'paid' reduce a balance — not pending ones awaiting
/// confirmation, and not legacy 'completed' rows.
Map<String, double> computePairwiseDebts({
  required String myId,
  required List<ExpenseModel> expenses,
  required List<SettlementModel> settlements,
}) {
  final pair = <String, double>{};
  // Each split user owes every payer their share of the split, in
  // proportion to what that payer paid (one payer → the whole split), the
  // same flows as the backend ledger.
  for (final expense in expenses) {
    final paid = expense.payers.fold<double>(0, (s, p) => s + p.amount);
    if (paid <= 0) continue;
    for (final payer in expense.payers) {
      final share = payer.amount / paid;
      for (final split in expense.splits) {
        if (split.userId == payer.userId) continue;
        if (payer.userId == myId) {
          pair[split.userId] = (pair[split.userId] ?? 0) - split.owedShare * share;
        } else if (split.userId == myId) {
          pair[payer.userId] = (pair[payer.userId] ?? 0) + split.owedShare * share;
        }
      }
    }
  }
  for (final s in settlements) {
    if (!s.countsTowardBalance) continue;
    if (s.fromUser.id == myId) {
      pair[s.toUser.id] = (pair[s.toUser.id] ?? 0) - s.amount;
    } else if (s.toUser.id == myId) {
      pair[s.fromUser.id] = (pair[s.fromUser.id] ?? 0) + s.amount;
    }
  }
  return pair;
}

/// Sum of PENDING settlements the user has already initiated TO each other
/// person (awaiting that person's confirmation). Used so "Settle Up" only
/// asks for the amount that isn't already in flight — preventing a second
/// settlement that would double-pay the same debt.
Map<String, double> computePendingOutgoing({
  required String myId,
  required List<SettlementModel> settlements,
}) {
  final out = <String, double>{};
  for (final s in settlements) {
    if (s.status != SettlementStatus.pending) continue;
    if (s.fromUser.id == myId) {
      out[s.toUser.id] = (out[s.toUser.id] ?? 0) + s.amount;
    }
  }
  return out;
}

enum GroupTab { balances, expenses, activity, totals }

final groupTabProvider = StateProvider<GroupTab>((ref) => GroupTab.expenses);
