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

final groupDetailProvider =
    FutureProvider.family<GroupDetail, String>((ref, groupId) async {
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
  final balances = <String, double>{
    for (final m in members) m.id: 0,
  };
  for (final expense in expenses) {
    final paidBy = expense.paidBy.id;
    for (final split in expense.splits) {
      if (split.userId == paidBy) continue;
      balances[paidBy] = (balances[paidBy] ?? 0) + split.owedShare;
      balances[split.userId] =
          (balances[split.userId] ?? 0) - split.owedShare;
    }
  }
  for (final s in settlements) {
    if (s.status == SettlementStatus.failed) continue;
    balances[s.fromUser.id] =
        (balances[s.fromUser.id] ?? 0) + s.amount;
    balances[s.toUser.id] = (balances[s.toUser.id] ?? 0) - s.amount;
  }
  return balances;
}

enum GroupTab { balances, expenses }

final groupTabProvider = StateProvider<GroupTab>((ref) => GroupTab.expenses);
