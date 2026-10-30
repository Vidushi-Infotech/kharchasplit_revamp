import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/activities/activities_repository.dart';
import '../../../models/activity_model.dart';
import '../../auth/state/auth_provider.dart';

final activityFeedProvider =
    AsyncNotifierProvider<ActivityFeedNotifier, List<ActivityModel>>(
      ActivityFeedNotifier.new,
    );

class ActivityFeedNotifier extends AsyncNotifier<List<ActivityModel>> {
  static const _pageSize = 50;

  /// Pages loaded so far, and whether the server has more.
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  Future<List<ActivityModel>> build() async {
    _page = 1;
    final user = ref.watch(authProvider).user;
    if (user == null) return const [];
    final result = await ref
        .read(activitiesRepositoryProvider)
        .listForUser(user.id, limit: _pageSize);
    _hasMore = result.activities.length == _pageSize;
    return result.activities;
  }

  /// The next page, appended (the feed calls this near its end). Once at
  /// a time; a failure just leaves the list as it is.
  Future<void> loadMore() async {
    final user = ref.read(authProvider).user;
    final current = state.value;
    if (!_hasMore || _loadingMore || user == null || current == null) return;
    _loadingMore = true;
    try {
      final result = await ref
          .read(activitiesRepositoryProvider)
          .listForUser(user.id, page: _page + 1, limit: _pageSize);
      _page += 1;
      _hasMore = result.activities.length == _pageSize;
      final seen = {for (final a in current) a.id};
      state = AsyncData([
        ...current,
        ...result.activities.where((a) => !seen.contains(a.id)),
      ]);
    } catch (_) {
      // Stays as it is; scrolling again retries.
    } finally {
      _loadingMore = false;
    }
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
      state = state.whenData(
        (items) => items
            .map((a) => a.id == activityId ? a.copyWith(isRead: true) : a)
            .toList(),
      );
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
        (items) => items.map((a) => a.copyWith(isRead: true)).toList(),
      );
    } catch (_) {
      // Best-effort.
    }
  }
}

enum ActivityFilter { all, expenses, settlements, groups }

final activityFilterProvider = StateProvider<ActivityFilter>(
  (ref) => ActivityFilter.all,
);

final filteredActivityFeedProvider = Provider<AsyncValue<List<ActivityModel>>>((
  ref,
) {
  final feedAsync = ref.watch(activityFeedProvider);
  final filter = ref.watch(activityFilterProvider);

  return feedAsync.whenData((activities) {
    if (filter == ActivityFilter.all) return activities;
    return activities.where((a) => activityFilterOf(a.type) == filter).toList();
  });
});

/// Which filter chip an event belongs to (never [ActivityFilter.all]).
/// Unknown events only show under All.
ActivityFilter? activityFilterOf(ActivityType type) => switch (type) {
  ActivityType.expenseAdded ||
  ActivityType.expenseEdited ||
  ActivityType.expenseDeleted ||
  ActivityType.commentAdded => ActivityFilter.expenses,
  ActivityType.settled ||
  ActivityType.settlementConfirmed ||
  ActivityType.settlementDeleted => ActivityFilter.settlements,
  ActivityType.groupCreated ||
  ActivityType.groupUpdated ||
  ActivityType.groupArchived ||
  ActivityType.groupDeleted ||
  ActivityType.memberAdded ||
  ActivityType.memberRemoved ||
  ActivityType.memberRoleUpdated => ActivityFilter.groups,
  ActivityType.other => null,
};
