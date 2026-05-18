import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../../groups/state/groups_provider.dart';

// These providers source from groupsProvider (the full list, up to 50) — NOT
// from dashboardProvider.recentGroups, which caps at 5 and was hiding
// higher-balance groups from the You're-Owed / You-Owe detail screens. The
// dashboard's *summary cards* still use the backend-aggregated totals, so
// the per-group breakdown here now sums to the same number.

/// Provider for groups where user is owed money (myBalance > 0)
final owedToMeGroupsProvider = Provider<List<GroupModel>>((ref) {
  final groups = ref.watch(groupsProvider).value ?? const <GroupModel>[];
  return groups
      .where((g) => g.myBalance > 0)
      .toList()
    ..sort((a, b) => b.myBalance.compareTo(a.myBalance));
});

/// Provider for groups where user owes money (myBalance < 0)
final iOweGroupsProvider = Provider<List<GroupModel>>((ref) {
  final groups = ref.watch(groupsProvider).value ?? const <GroupModel>[];
  return groups
      .where((g) => g.myBalance < 0)
      .toList()
    ..sort((a, b) => a.myBalance.compareTo(b.myBalance));
});

/// Provider for calculating total amount owed to user
final totalOwedToMeProvider = Provider<double>((ref) {
  final groups = ref.watch(owedToMeGroupsProvider);
  return groups.fold<double>(0, (sum, g) => sum + g.myBalance);
});

/// Provider for calculating total amount user owes
final totalIOweProvider = Provider<double>((ref) {
  final groups = ref.watch(iOweGroupsProvider);
  return groups.fold<double>(0, (sum, g) => sum + g.myBalance.abs());
});
