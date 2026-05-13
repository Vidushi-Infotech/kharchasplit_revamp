import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/groups_provider.dart';

class FriendSummary {
  const FriendSummary({
    required this.user,
    required this.sharedGroupIds,
  });

  final UserModel user;
  final List<String> sharedGroupIds;
}

/// Friends are everyone the current user shares at least one group with.
/// Derived from `groupsProvider` so it stays in lockstep with the groups list.
final friendsProvider = Provider<AsyncValue<List<FriendSummary>>>((ref) {
  final me = ref.watch(authProvider).user;
  return ref.watch(groupsProvider).whenData((groups) {
    final byUserId = <String, FriendSummary>{};
    for (final group in groups) {
      for (final member in group.members) {
        if (me != null && member.id == me.id) continue;
        final existing = byUserId[member.id];
        if (existing == null) {
          byUserId[member.id] = FriendSummary(
            user: member,
            sharedGroupIds: [group.id],
          );
        } else {
          byUserId[member.id] = FriendSummary(
            user: existing.user,
            sharedGroupIds: [...existing.sharedGroupIds, group.id],
          );
        }
      }
    }
    final list = byUserId.values.toList()
      ..sort((a, b) => a.user.name.compareTo(b.user.name));
    return list;
  });
});
