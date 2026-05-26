// Template: frontend/lib/modules/<feature>/state/<feature>_provider.dart
//
// AsyncNotifierProvider skeleton mirroring frontend/lib/modules/activity/state/activity_feed_provider.dart.
// Swap to NotifierProvider for sync state, or StateProvider for trivial form state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart'; // <-- only if you need StateProvider

import '../../auth/state/auth_provider.dart';
import '../../../data/<feature>/<feature>_repository.dart';
import '../../../models/<feature>_model.dart';

final <feature>Provider =
    AsyncNotifierProvider<<Feature>Notifier, List<<Feature>Model>>(
  <Feature>Notifier.new,
);

class <Feature>Notifier extends AsyncNotifier<List<<Feature>Model>> {
  @override
  Future<List<<Feature>Model>> build() async {
    // Re-runs whenever auth changes — guard for unauthenticated.
    final user = ref.watch(authProvider).user;
    if (user == null) return const [];
    final repo = ref.read(<feature>RepositoryProvider);
    return repo.listForUser(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Example mutation — propagates optimistic UI then re-fetches on error.
  Future<void> add(<Feature>Model item) async {
    final repo = ref.read(<feature>RepositoryProvider);
    final previous = state;
    state = state.whenData((items) => [item, ...items]);
    try {
      await repo.create(item);
    } catch (_) {
      state = previous; // rollback
      rethrow;
    }
  }
}
