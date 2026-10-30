import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/settlements/settlements_repository.dart';
import '../../../models/group_model.dart';
import '../../../models/settlement_model.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';
import 'pending_settlements_provider.dart';

/// Records one payment from the Record a payment screen and refreshes
/// every balance that shows it. Throws on failure (the screen says so).
class RecordPaymentController {
  RecordPaymentController(this._ref);
  final Ref _ref;

  Future<void> record({
    required GroupModel group,
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? notes,
    SettlementMethod? method,
    DateTime? paidOn,
  }) async {
    final now = DateTime.now();
    final earlier =
        paidOn != null &&
        DateTime(
          paidOn.year,
          paidOn.month,
          paidOn.day,
        ).isBefore(DateTime(now.year, now.month, now.day));
    await _ref
        .read(settlementsRepositoryProvider)
        .create(
          groupId: group.id,
          fromUserId: fromUserId,
          toUserId: toUserId,
          amount: amount,
          currency: group.currency,
          notes: notes,
          method: method,
          // Midday of an earlier day; today's payments get the server's now.
          paidAt: earlier
              ? DateTime(paidOn.year, paidOn.month, paidOn.day, 12)
              : null,
        );
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(groupDetailProvider(group.id));
    // Group cards' balances; friendsProvider refetches off this too.
    _ref.invalidate(groupsProvider);
    // Settlements are final on creation; refresh the pending sections too
    // so any legacy pending entries stay in sync.
    _ref.invalidate(pendingOutgoingSettlementsProvider(group.id));
    _ref.invalidate(pendingIncomingSettlementsProvider(group.id));
  }
}

final recordPaymentControllerProvider = Provider<RecordPaymentController>(
  RecordPaymentController.new,
);
