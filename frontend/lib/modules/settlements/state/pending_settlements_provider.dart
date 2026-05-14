import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/settlements/settlements_repository.dart';
import '../../../models/settlement_model.dart';
import '../../auth/state/auth_provider.dart';

/// Settlements in [groupId] that are still pending and where the current user
/// is the *recipient* (someone else paid them, awaiting their confirmation).
///
/// Returns an empty list if the user isn't signed in. Re-fires when the
/// underlying repository call succeeds; invalidate from a caller after a
/// confirm/decline action to refresh.
final pendingIncomingSettlementsProvider =
    FutureProvider.family<List<SettlementModel>, String>((ref, groupId) async {
  final me = ref.watch(authProvider).user;
  if (me == null) return const [];
  final all =
      await ref.read(settlementsRepositoryProvider).listForGroup(groupId);
  return all
      .where((s) =>
          s.status == SettlementStatus.pending && s.toUser.id == me.id)
      .toList();
});

/// Same idea, flipped — pending settlements the current user *sent* that
/// are still waiting for the recipient to confirm. Used to show a Cancel
/// affordance so the sender can withdraw the promise.
final pendingOutgoingSettlementsProvider =
    FutureProvider.family<List<SettlementModel>, String>((ref, groupId) async {
  final me = ref.watch(authProvider).user;
  if (me == null) return const [];
  final all =
      await ref.read(settlementsRepositoryProvider).listForGroup(groupId);
  return all
      .where((s) =>
          s.status == SettlementStatus.pending && s.fromUser.id == me.id)
      .toList();
});
