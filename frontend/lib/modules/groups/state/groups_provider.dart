import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/connectivity_provider.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/group_model.dart';
import '../../auth/state/auth_provider.dart';

/// Live list of the current user's groups (server-backed).
final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<GroupModel>>(GroupsNotifier.new);

class GroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  @override
  Future<List<GroupModel>> build() async {
    final user = ref.watch(authProvider).user;
    // Auto-refresh when the device comes back online so the list reflects
    // anything that changed server-side while we were disconnected.
    ref.listen(onReconnectStreamProvider, (_, __) {
      refresh();
    });
    if (user == null) return const <GroupModel>[];
    return ref.read(groupsRepositoryProvider).listForUser(user.id);
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = const AsyncData(<GroupModel>[]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(groupsRepositoryProvider).listForUser(user.id),
    );
  }

  /// Creates a group via the API and prepends it to local state.
  /// Throws on failure so the caller can surface an inline error.
  Future<GroupModel> addGroup({
    required String name,
    String? description,
    String? coverImageBase64,
    String currency = 'INR',
    List<CreateGroupMember> members = const [],
  }) async {
    final repo = ref.read(groupsRepositoryProvider);
    final created = await repo.create(
      name: name,
      description: description,
      coverImageBase64: coverImageBase64,
      currency: currency,
      members: members,
    );
    // Re-fetch from server so the optimistic state matches what the
    // detail/list endpoints will return (member_count, totals, etc.).
    await refresh();
    return created;
  }

  /// Edits an existing group. Only the admin/creator can call this
  /// (backend enforces). Refetches the list so list cards reflect the
  /// new name / photo right away.
  Future<GroupModel> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? coverImageBase64,
    String? currency,
  }) async {
    final repo = ref.read(groupsRepositoryProvider);
    final updated = await repo.update(
      groupId,
      name: name,
      description: description,
      coverImageBase64: coverImageBase64,
      currency: currency,
    );
    await refresh();
    return updated;
  }
}
