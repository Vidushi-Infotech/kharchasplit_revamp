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
    if (user == null) return DashboardData.empty;

    // Surface the current groups list immediately, then layer the API
    // summary on top — keeps the recent-groups carousel snappy.
    final groups = ref.watch(groupsProvider).value ?? const <GroupModel>[];
    final recentGroups = groups.take(_recentGroupsCount).toList();

    final summary = await ref
        .read(dashboardRepositoryProvider)
        .getForUser(user.id, recentLimit: _recentExpensesCount);

    return DashboardData(
      totalBalance: summary.totalBalance,
      youAreOwed: summary.youAreOwed,
      youOwe: summary.youOwe,
      recentGroups: recentGroups,
      recentExpenses: summary.recentExpenses,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    // Refresh the underlying groups list too — otherwise build() reuses
    // the cached value and the carousel stays stale.
    await ref.read(groupsProvider.notifier).refresh();
    state = await AsyncValue.guard(build);
  }
}
