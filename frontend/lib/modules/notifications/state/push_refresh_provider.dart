import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/push_service.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';
import '../../settlements/state/pending_settlements_provider.dart';

/// Push types that change balances, membership or the group list. When one
/// arrives while the app is in the foreground, the affected data is
/// refetched so whatever screen is open shows it without a pull-to-refresh
/// (e.g. the receiver sees "Settled" the moment the payer settles).
const _balanceTypes = <String>{
  'EXPENSE_ADDED',
  'EXPENSE_UPDATED',
  'EXPENSE_DELETED',
  'SETTLEMENT_CREATED',
  'SETTLEMENT_CONFIRMED',
  'SETTLEMENT_DELETED',
  'BALANCE_WRITTEN_OFF',
  'PAYMENT_NOT_RECEIVED',
  'SETTLE_ALL_RECEIVED',
};

const _groupListTypes = <String>{
  'GROUP_INVITE',
  'GROUP_ARCHIVED',
  'GROUP_COMPLETED',
  'GROUP_DELETED',
  'REMOVED_FROM_GROUP',
  'MEMBER_ADDED',
  'MEMBER_LEFT',
  'MEMBER_REMOVED',
  // Group cards carry balances too; a rejected payment or a settle-all
  // (which spans groups, no groupId) changes them.
  'PAYMENT_NOT_RECEIVED',
  'SETTLE_ALL_RECEIVED',
};

/// Keep-alive listener; read it once from the app root to start it.
final pushRefreshProvider = Provider<void>((ref) {
  if (!PushService.isSupportedPlatform) return;

  final StreamSubscription sub =
      PushService.instance.onForegroundMessage.listen((message) {
    final type = (message.data['type'] ?? '').toString();
    final groupId = (message.data['groupId'] ?? '').toString();
    final touchesBalances = _balanceTypes.contains(type);
    final touchesGroups = _groupListTypes.contains(type);
    if (!touchesBalances && !touchesGroups) return;

    ref.invalidate(dashboardProvider);
    if (touchesGroups) ref.invalidate(groupsProvider);
    if (groupId.isNotEmpty) {
      ref.invalidate(groupDetailProvider(groupId));
      if (touchesBalances) {
        ref.invalidate(pendingIncomingSettlementsProvider(groupId));
        ref.invalidate(pendingOutgoingSettlementsProvider(groupId));
      }
    }
  });
  ref.onDispose(sub.cancel);
});
