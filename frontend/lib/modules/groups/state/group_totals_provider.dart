import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/state/auth_provider.dart';
import 'group_detail_provider.dart';
import 'group_totals_calculator.dart';

/// Selected period on a group's Totals tab. Per group, so two open groups
/// don't share a filter; released with the screen.
final groupTotalsPeriodProvider = StateProvider.autoDispose
    .family<TotalsPeriod, String>((ref, groupId) => TotalsPeriod.thisMonth);

/// Totals for the group in the selected period, derived from the already
/// loaded [groupDetailProvider] — no extra request. Null until the detail
/// has loaded.
final groupTotalsProvider = Provider.autoDispose.family<GroupTotals?, String>((
  ref,
  groupId,
) {
  final detail = ref.watch(groupDetailProvider(groupId)).value;
  if (detail == null) return null;
  return computeGroupTotals(
    expenses: detail.expenses,
    settlements: detail.settlements,
    members: detail.members,
    myId: ref.watch(myIdProvider),
    period: ref.watch(groupTotalsPeriodProvider(groupId)),
    now: DateTime.now(),
  );
});
