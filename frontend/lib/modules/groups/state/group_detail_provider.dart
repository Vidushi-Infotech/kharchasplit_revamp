import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/expenses/expenses_repository.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/expense_model.dart';
import '../../../models/group_model.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';

class GroupDetail {
  const GroupDetail({
    required this.group,
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.memberBalances,
    required this.totalExpense,
  });

  final GroupModel group;
  final List<UserModel> members;
  final List<ExpenseModel> expenses;
  final List<SettlementModel> settlements;
  final Map<String, double> memberBalances;
  final double totalExpense;
}

final groupDetailProvider = FutureProvider.family<GroupDetail, String>((
  ref,
  groupId,
) async {
  final groupsRepo = ref.read(groupsRepositoryProvider);
  final expensesRepo = ref.read(expensesRepositoryProvider);
  final settlementsRepo = ref.read(settlementsRepositoryProvider);

  // Fetch group + expenses + settlements in parallel.
  final results = await Future.wait([
    groupsRepo.getById(groupId),
    expensesRepo.listForGroup(groupId),
    settlementsRepo.listForGroup(groupId),
  ]);

  final group = results[0] as GroupModel;
  final expenses = results[1] as List<ExpenseModel>;
  final settlements = results[2] as List<SettlementModel>;

  final balances = _computeBalances(group.members, expenses, settlements);
  final totalExpense = expenses.fold<double>(0, (s, e) => s + e.amount);

  return GroupDetail(
    group: group,
    members: group.members,
    expenses: expenses,
    settlements: settlements,
    memberBalances: balances,
    totalExpense: totalExpense,
  );
});

/// Mirrors backend `groupService._computeBalances`:
/// positive = others owe me, negative = I owe.
///
/// Combines expense splits AND settlements:
///   expense:    paidBy is owed; each split user owes
///   settlement: fromUser's debt shrinks (+); toUser's claim shrinks (-)
///
/// Pending + completed settlements both count; failed/cancelled don't.
Map<String, double> _computeBalances(
  List<UserModel> members,
  List<ExpenseModel> expenses,
  List<SettlementModel> settlements,
) {
  final balances = <String, double>{for (final m in members) m.id: 0};
  for (final expense in expenses) {
    final paidBy = expense.paidBy.id;
    for (final split in expense.splits) {
      if (split.userId == paidBy) continue;
      balances[paidBy] = (balances[paidBy] ?? 0) + split.owedShare;
      balances[split.userId] = (balances[split.userId] ?? 0) - split.owedShare;
    }
  }
  for (final s in settlements) {
    if (s.status == SettlementStatus.failed) continue;
    balances[s.fromUser.id] = (balances[s.fromUser.id] ?? 0) + s.amount;
    balances[s.toUser.id] = (balances[s.toUser.id] ?? 0) - s.amount;
  }
  return balances;
}

/// Net pairwise balance between [myId] and every other person, from myId's
/// perspective:
///   pair[otherId] > 0  → I owe them that much
///   pair[otherId] < 0  → they owe me |that much|
///   pair[otherId] ~ 0  → settled
///
/// Only CONFIRMED (completed) settlements reduce a balance — a pending
/// settlement is still awaiting confirmation and must not zero the debt.
Map<String, double> computePairwiseDebts({
  required String myId,
  required List<ExpenseModel> expenses,
  required List<SettlementModel> settlements,
}) {
  final pair = <String, double>{};
  for (final expense in expenses) {
    final paidBy = expense.paidBy.id;
    if (paidBy == myId) {
      for (final split in expense.splits) {
        if (split.userId == myId) continue;
        pair[split.userId] = (pair[split.userId] ?? 0) - split.owedShare;
      }
    } else {
      for (final split in expense.splits) {
        if (split.userId != myId) continue;
        pair[paidBy] = (pair[paidBy] ?? 0) + split.owedShare;
      }
    }
  }
  for (final s in settlements) {
    if (s.status != SettlementStatus.completed) continue;
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

enum GroupTab { balances, expenses, activity }

final groupTabProvider = StateProvider<GroupTab>((ref) => GroupTab.expenses);
