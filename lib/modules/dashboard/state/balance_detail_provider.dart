import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../state/dashboard_provider.dart';

/// Provider for groups where user is owed money (myBalance > 0)
final owedToMeGroupsProvider = Provider<List<GroupModel>>((ref) {
  final dashboard = ref.watch(dashboardProvider);
  final groups = dashboard.recentGroups
      .where((g) => g.myBalance > 0)
      .toList()
    ..sort((a, b) => b.myBalance.compareTo(a.myBalance)); // Highest first
  return groups;
});

/// Provider for groups where user owes money (myBalance < 0)
final iOweGroupsProvider = Provider<List<GroupModel>>((ref) {
  final dashboard = ref.watch(dashboardProvider);
  final groups = dashboard.recentGroups
      .where((g) => g.myBalance < 0)
      .toList()
    ..sort((a, b) => a.myBalance.compareTo(b.myBalance)); // Most owed first
  return groups;
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
