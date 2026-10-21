import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/keep_alive_for.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/expense_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/groups_provider.dart';
import 'friends_provider.dart';

/// Expenses that involve both the signed-in user and [friendId], newest
/// first. Display only — balances come from the server via
/// [friendByIdProvider], never from summing these.
final friendSharedExpensesProvider = FutureProvider.autoDispose
    .family<List<ExpenseModel>, String>((ref, friendId) async {
  keepAliveFor(ref, const Duration(minutes: 5));
  final myId = ref.watch(authProvider.select((s) => s.user?.id));
  if (myId == null) return const [];
  final groups = await ref.watch(groupsProvider.future);
  var balanceGroups = const <FriendGroupBalance>[];
  String? directGroupId;
  try {
    final friends = await ref.watch(friendsProvider.future);
    final friend = friends.firstWhereOrNull((f) => f.user.id == friendId);
    balanceGroups = friend?.groups ?? const [];
    directGroupId = friend?.directGroupId;
  } catch (_) {
    // Balances failing shouldn't hide the expense history.
  }

  // Current shared groups, plus groups that still carry a balance with the
  // friend (they may have left, or the group may be archived), plus the
  // hidden non-group one (never in groupsProvider).
  final groupIds = <String>{
    for (final g in groups)
      if (g.members.any((m) => m.id == friendId)) g.id,
    ...balanceGroups.map((g) => g.groupId),
    ?directGroupId,
  };
  if (groupIds.isEmpty) return const [];

  final repo = ref.read(expensesRepositoryProvider);
  final perGroup = await Future.wait(groupIds.map(repo.listAllForGroup));

  bool involves(ExpenseModel e, String id) =>
      e.paidBy.id == id || e.splits.any((s) => s.userId == id);

  final shared = [
    for (final list in perGroup)
      for (final e in list)
        if (involves(e, friendId) && involves(e, myId)) e,
  ]..sort((a, b) => b.date.compareTo(a.date));
  return shared;
});

/// Friend-detail actions that hit the API.
final friendActionsProvider = Provider<FriendActions>(FriendActions.new);

class FriendActions {
  FriendActions(this._ref);
  final Ref _ref;

  /// Sends a payment reminder to [friendId] for [groupId]. Throws
  /// [GroupsApiException] with the server's message on failure (e.g. the
  /// one-per-6h cooldown), so the UI can show it verbatim.
  Future<void> remind({required String groupId, required String friendId}) {
    return _ref
        .read(groupsRepositoryProvider)
        .sendReminder(groupId: groupId, userId: friendId);
  }

  /// Id of the hidden non-group-expenses group with [friendId]: [knownId]
  /// when the friends list already has it, otherwise get-or-create on the
  /// server (POST /groups/direct). Throws [GroupsApiException] on failure.
  Future<String> directGroupFor(String friendId, {String? knownId}) async {
    if (knownId != null) return knownId;
    return _ref.read(groupsRepositoryProvider).directGroupWith(friendId);
  }

  /// Pulls fresh balances and shared expenses.
  Future<void> refresh(String friendId) async {
    _ref.invalidate(friendsProvider);
    _ref.invalidate(friendSharedExpensesProvider(friendId));
    await _ref.read(friendsProvider.future);
  }
}
