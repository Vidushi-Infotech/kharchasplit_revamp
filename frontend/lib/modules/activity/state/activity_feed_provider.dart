import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/activities/activities_repository.dart';
import '../../../models/activity_model.dart';
import '../../auth/state/auth_provider.dart';

final activityFeedProvider =
    AsyncNotifierProvider<ActivityFeedNotifier, List<ActivityModel>>(
        ActivityFeedNotifier.new);

class ActivityFeedNotifier extends AsyncNotifier<List<ActivityModel>> {
  @override
  Future<List<ActivityModel>> build() async {
    final user = ref.watch(authProvider).user;
    if (user == null) return const [];
    final result =
        await ref.read(activitiesRepositoryProvider).listForUser(user.id);
    return result.activities;
  }

  /// Re-fetches while keeping the current data on screen. `invalidateSelf`
  /// re-runs [build] with refresh semantics (previous value retained,
  /// `isRefreshing == true`), so `.when()` keeps rendering the data branch
  /// instead of dropping to a skeleton. It also disposes and re-registers the
  /// listeners set up in [build], which calling `build()` by hand never did.
  /// A failed fetch lands in [state] rather than being thrown, matching the
  /// old `AsyncValue.guard` behaviour.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Already reflected in state.
    }
  }

  Future<void> markAsRead(String activityId) async {
    final repo = ref.read(activitiesRepositoryProvider);
    try {
      await repo.markAsRead(activityId);
      state = state.whenData((items) =>
          items.map((a) => a.id == activityId ? a.copyWith(isRead: true) : a).toList());
    } catch (_) {
      // Silent — UI already shows the activity, marking is best-effort.
    }
  }

  Future<void> markAllAsRead() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      await ref.read(activitiesRepositoryProvider).markAllAsRead(user.id);
      state = state.whenData(
          (items) => items.map((a) => a.copyWith(isRead: true)).toList());
    } catch (_) {
      // Best-effort.
    }
  }
}

enum ActivityFilter { all, expenses, settlements, groups }

final activityFilterProvider =
    StateProvider<ActivityFilter>((ref) => ActivityFilter.all);

final filteredActivityFeedProvider =
    Provider<AsyncValue<List<ActivityModel>>>((ref) {
  final feedAsync = ref.watch(activityFeedProvider);
  final filter = ref.watch(activityFilterProvider);

  return feedAsync.whenData((activities) {
    switch (filter) {
      case ActivityFilter.all:
        return activities;
      case ActivityFilter.expenses:
        return activities
            .where((a) =>
                a.type == ActivityType.expenseAdded ||
                a.type == ActivityType.expenseEdited ||
                a.type == ActivityType.expenseDeleted)
            .toList();
      case ActivityFilter.settlements:
        return activities
            .where((a) => a.type == ActivityType.settled)
            .toList();
      case ActivityFilter.groups:
        return activities
            .where((a) =>
                a.type == ActivityType.groupCreated ||
                a.type == ActivityType.memberAdded ||
                a.type == ActivityType.memberRemoved)
            .toList();
    }
  });
});
