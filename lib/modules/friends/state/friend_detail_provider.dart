import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/expenses/expenses_repository.dart';
import '../../../models/expense_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/groups_provider.dart';

class FriendDetail {
  const FriendDetail({
    required this.friend,
    required this.balanceYouOwe,
    required this.sharedExpenses,
  });

  final UserModel friend;

  /// Positive = you owe them; negative = they owe you.
  final double balanceYouOwe;

  final List<ExpenseModel> sharedExpenses;
}

final friendDetailProvider =
    FutureProvider.family<FriendDetail, String>((ref, friendId) async {
  final me = ref.watch(authProvider).user;
  final groups = ref.watch(groupsProvider).value ?? const [];

  final sharedGroups =
      groups.where((g) => g.members.any((m) => m.id == friendId)).toList();

  if (sharedGroups.isEmpty || me == null) {
    return FriendDetail(
      friend: UserModel(
        id: friendId,
        name: 'Unknown',
        email: '',
        phone: '',
        createdAt: DateTime.now(),
      ),
      balanceYouOwe: 0,
      sharedExpenses: const [],
    );
  }

  final friend = sharedGroups
      .expand((g) => g.members)
      .firstWhere((m) => m.id == friendId);

  // Fetch expenses for every shared group in parallel.
  final repo = ref.read(expensesRepositoryProvider);
  final perGroup = await Future.wait(
    sharedGroups.map((g) => repo.listForGroup(g.id)),
  );

  // Keep only expenses that involve both me and the friend.
  // Compute net: positive split.owedShare for friend means I (payer) am owed
  // by them; for me means I owe payer.
  double balance = 0; // positive = I owe friend
  final shared = <ExpenseModel>[];
  for (final expenses in perGroup) {
    for (final e in expenses) {
      final friendInvolved =
          e.paidBy.id == friendId || e.splits.any((s) => s.userId == friendId);
      final meInvolved =
          e.paidBy.id == me.id || e.splits.any((s) => s.userId == me.id);
      if (!friendInvolved || !meInvolved) continue;
      shared.add(e);

      if (e.paidBy.id == friendId) {
        // Friend paid; I owe my share.
        for (final s in e.splits) {
          if (s.userId == me.id) balance += s.owedShare;
        }
      } else if (e.paidBy.id == me.id) {
        // I paid; friend owes their share.
        for (final s in e.splits) {
          if (s.userId == friendId) balance -= s.owedShare;
        }
      }
    }
  }

  shared.sort((a, b) => b.date.compareTo(a.date));

  return FriendDetail(
    friend: friend,
    balanceYouOwe: balance,
    sharedExpenses: shared,
  );
});
