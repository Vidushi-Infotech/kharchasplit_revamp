import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../../groups/state/groups_provider.dart';

// Sources from groupsProvider (the full list, up to 50). The detail screens
// filter by PAIR-level totals (youAreOwedInGroup / youOweInGroup), NOT by the
// per-group net (myBalance). Reason: in a group like "Dami" a user may net
// +566 (myBalance positive) but still owe one specific member -1633; without
// pair-level filtering that group would vanish from the "You owe" drill-down
// even though the homescreen counts ₹1633 of debt there.
//
// Backwards compatibility: when an older backend hasn't shipped the new
// fields, GroupModel.fromJson derives them from myBalance so existing
// installs continue to work.

const double _epsilon = 0.005;

/// Groups where someone in the group owes the user money.
final owedToMeGroupsProvider = Provider<List<GroupModel>>((ref) {
  final groups = ref.watch(groupsProvider).value ?? const <GroupModel>[];
  return groups
      .where((g) => g.youAreOwedInGroup > _epsilon)
      .toList()
    ..sort((a, b) => b.youAreOwedInGroup.compareTo(a.youAreOwedInGroup));
});

/// Groups where the user owes someone money.
final iOweGroupsProvider = Provider<List<GroupModel>>((ref) {
  final groups = ref.watch(groupsProvider).value ?? const <GroupModel>[];
  return groups
      .where((g) => g.youOweInGroup > _epsilon)
      .toList()
    ..sort((a, b) => b.youOweInGroup.compareTo(a.youOweInGroup));
});

/// Total amount owed to the user (sum of pair-level positives across all groups).
final totalOwedToMeProvider = Provider<double>((ref) {
  final groups = ref.watch(owedToMeGroupsProvider);
  return groups.fold<double>(0, (sum, g) => sum + g.youAreOwedInGroup);
});

/// Total amount the user owes (sum of pair-level debts across all groups).
final totalIOweProvider = Provider<double>((ref) {
  final groups = ref.watch(iOweGroupsProvider);
  return groups.fold<double>(0, (sum, g) => sum + g.youOweInGroup);
});
