import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/settlements/settlements_repository.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';
import 'pending_settlements_provider.dart';

/// Receiver-side "Not received": deletes a payment someone recorded to you.
/// The server also removes the rest of its settle-all batch, if any, and
/// notifies the payer (PAYMENT_NOT_RECEIVED).
class NotReceivedController {
  NotReceivedController(this._ref);
  final Ref _ref;

  /// Throws [SettlementsApiException] with the server's wording on failure.
  Future<void> markNotReceived({
    required String settlementId,
    required String groupId,
  }) async {
    await _ref.read(settlementsRepositoryProvider).delete(settlementId);
    _ref.invalidate(groupDetailProvider(groupId));
    // Group cards' balances; friendsProvider refetches off this too. A
    // settle-all batch can span groups, so the list is always refreshed.
    _ref.invalidate(groupsProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(pendingIncomingSettlementsProvider(groupId));
    _ref.invalidate(pendingOutgoingSettlementsProvider(groupId));
  }
}

final notReceivedControllerProvider = Provider<NotReceivedController>(
  NotReceivedController.new,
);
