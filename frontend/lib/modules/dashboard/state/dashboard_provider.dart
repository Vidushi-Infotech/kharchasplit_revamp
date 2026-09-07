import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/connectivity_provider.dart';
import '../../../data/dashboard/dashboard_repository.dart';
import '../../../models/expense_model.dart';
import '../../../models/group_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/groups_provider.dart';

class DashboardData {
  const DashboardData({
    required this.totalBalance,
    required this.youAreOwed,
    required this.youOwe,
    required this.recentGroups,
    required this.recentExpenses,
  });

  final double totalBalance;
  final double youAreOwed;
  final double youOwe;
  final List<GroupModel> recentGroups;
  final List<ExpenseModel> recentExpenses;

  static const empty = DashboardData(
    totalBalance: 0,
    youAreOwed: 0,
    youOwe: 0,
    recentGroups: <GroupModel>[],
    recentExpenses: <ExpenseModel>[],
  );

  DashboardData copyWith({List<GroupModel>? recentGroups}) => DashboardData(
        totalBalance: totalBalance,
        youAreOwed: youAreOwed,
        youOwe: youOwe,
        recentGroups: recentGroups ?? this.recentGroups,
        recentExpenses: recentExpenses,
      );
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(
        DashboardNotifier.new);

class DashboardNotifier extends AsyncNotifier<DashboardData> {
  static const int _recentGroupsCount = 5;
  static const int _recentExpensesCount = 10;

  @override
  Future<DashboardData> build() async {
    final user = ref.watch(authProvider).user;
    // Auto-refresh on reconnect so balances/recents are fresh.
    ref.listen(onReconnectStreamProvider, (_, __) {
      refresh();
    });

    // Keep the recent-groups carousel in sync with the groups list WITHOUT
    // rebuilding the whole dashboard. `ref.watch(groupsProvider)` here would
    // re-run build (and drop the screen to a skeleton) every time the groups
    // list refreshed; instead patch just the carousel slice in place.
    ref.listen(groupsProvider.select((s) => s.value), (_, groups) {
      final current = state.value;
      if (groups == null || current == null) return;
      state = AsyncData(current.copyWith(
        recentGroups: groups.take(_recentGroupsCount).toList(),
      ));
    });

    if (user == null) return DashboardData.empty;
    return _load(user.id);
  }

  Future<DashboardData> _load(String userId) async {
    // Surface the current groups list immediately, then layer the API
    // summary on top — keeps the recent-groups carousel snappy.
    final groups = ref.read(groupsProvider).value ?? const <GroupModel>[];
    final recentGroups = groups.take(_recentGroupsCount).toList();

    final summary = await ref
        .read(dashboardRepositoryProvider)
        .getForUser(userId, recentLimit: _recentExpensesCount);

    return DashboardData(
      totalBalance: summary.totalBalance,
      youAreOwed: summary.youAreOwed,
      youOwe: summary.youOwe,
      recentGroups: recentGroups,
      recentExpenses: summary.recentExpenses,
    );
  }

  /// Re-fetches while keeping the current data on screen. `invalidateSelf`
  /// re-runs [build] with refresh semantics (previous value retained,
  /// `isRefreshing == true`), so `.when()` keeps rendering the data branch
  /// instead of dropping to a skeleton. It also disposes and re-registers the
  /// listeners set up in [build], which calling `build()` by hand never did.
  /// A failed fetch lands in [state] rather than being thrown, matching the
  /// old `AsyncValue.guard` behaviour.
  ///
  /// The groups list is refreshed first so the carousel and the summary
  /// come from the same server snapshot.
  Future<void> refresh() async {
    await ref.read(groupsProvider.notifier).refresh();
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Already reflected in state.
    }
  }
}
