import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/groups/groups_repository.dart';
import 'group_detail_provider.dart';
import 'groups_provider.dart';

/// Total still owed inside the group, across ALL members (not just the
/// current user's pairs). Mirrors the backend's `GROUP_NOT_SETTLED` check:
/// per-person net = what they paid for others − what they owe, adjusted by
/// confirmed payments; the open amount is the sum of the positive nets.
double groupOpenAmount(GroupDetail detail) {
  final net = <String, double>{};
  void add(String id, double v) => net[id] = (net[id] ?? 0) + v;

  for (final e in detail.expenses) {
    for (final s in e.splits) {
      if (s.userId == e.paidBy.id) continue;
      add(e.paidBy.id, s.owedShare);
      add(s.userId, -s.owedShare);
    }
  }
  for (final s in detail.settlements) {
    if (!s.countsTowardBalance) continue;
    add(s.fromUser.id, s.amount);
    add(s.toUser.id, -s.amount);
  }
  // Ignore sub-paisa rounding dust per person.
  return net.values.where((v) => v > 0.01).fold<double>(0, (a, v) => a + v);
}

/// Thrown by [GroupLifecycleController.complete] when the group still has
/// open balances (client-side check or the server's 409 race).
class GroupNotSettledException implements Exception {
  const GroupNotSettledException(this.openAmount);
  final double openAmount;
}

/// Archive / unarchive / complete for the group detail screen. The API call
/// plus the cache refresh live here; dialogs and snackbars stay in
/// group_lifecycle_actions.dart.
class GroupLifecycleController {
  GroupLifecycleController(this._ref);
  final Ref _ref;

  GroupsRepository get _repo => _ref.read(groupsRepositoryProvider);

  void _refresh(String groupId) {
    _ref.invalidate(groupDetailProvider(groupId));
    _ref.invalidate(groupsProvider);
  }

  Future<void> archive(String groupId) async {
    await _repo.archive(groupId);
    _refresh(groupId);
  }

  Future<void> unarchive(String groupId) async {
    await _repo.unarchive(groupId);
    _refresh(groupId);
  }

  /// Marks the group complete. Throws [GroupNotSettledException] when the
  /// server reports open balances (someone recorded an expense meanwhile).
  Future<void> complete(String groupId) async {
    try {
      await _repo.complete(groupId);
    } on GroupsApiException catch (e) {
      if (e.code == 'GROUP_NOT_SETTLED') {
        final raw = e.data?['openAmount'];
        final open = raw is num
            ? raw.toDouble()
            : double.tryParse(raw?.toString() ?? '') ?? 0;
        // Balances changed under us — refetch so the screen shows them.
        _ref.invalidate(groupDetailProvider(groupId));
        throw GroupNotSettledException(open);
      }
      rethrow;
    }
    _refresh(groupId);
  }
}

final groupLifecycleControllerProvider = Provider<GroupLifecycleController>(
  GroupLifecycleController.new,
);
