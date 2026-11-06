import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/settlements/settlements_repository.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/settlement_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../friends/state/friends_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';

export '../../../data/settlements/settlements_repository.dart'
    show SettleAllLine;

/// One "Settle all balances" screen: a friend and one currency (currencies
/// are never netted together).
typedef SettleAllKey = ({String friendId, String currency});

class SettleAllState {
  const SettleAllState({
    this.current,
    this.balancesChanged = false,
    this.submitting = false,
    this.error,
  });

  /// The server's amounts after a 409 BALANCES_CHANGED; null = show the
  /// friend balances as loaded.
  final List<SettleAllLine>? current;

  /// Show the "Balances changed — check the new total" banner.
  final bool balancesChanged;
  final bool submitting;

  /// Server message to show (e.g. 400 "You don't owe X overall…").
  final String? error;
}

final settleAllControllerProvider = NotifierProvider.autoDispose
    .family<SettleAllController, SettleAllState, SettleAllKey>(
      SettleAllController.new,
    );

/// The per-group amounts on screen, > 0 = I owe the friend in that group.
/// From the friend's balances (GET /users/:id/friends, the same visible,
/// simplified-aware numbers the server compares against), replaced by the
/// server's `current` after a 409. `null` data = not a friend any more.
final settleAllLinesProvider = Provider.autoDispose
    .family<AsyncValue<List<SettleAllLine>?>, SettleAllKey>((ref, key) {
      final current = ref.watch(
        settleAllControllerProvider(key).select((s) => s.current),
      );
      if (current != null) return AsyncData(current);
      return ref.watch(friendByIdProvider(key.friendId)).whenData((friend) {
        if (friend == null) return null;
        return [
          for (final g in friend.groups)
            if (g.currency == key.currency && g.net.abs() > 0.005)
              SettleAllLine(
                groupId: g.groupId,
                groupName: g.groupName,
                amount: -g.net,
              ),
        ];
      });
    });

/// Net I pay across [lines] (> 0 = I owe overall).
double settleAllTotal(List<SettleAllLine> lines) =>
    lines.fold<double>(0, (sum, l) => sum + l.amount);

class SettleAllController extends Notifier<SettleAllState> {
  SettleAllController(this.key);
  final SettleAllKey key;

  @override
  SettleAllState build() => const SettleAllState();

  /// Records the payment for exactly [shown] (what the screen displayed).
  /// Returns true on success. On 409 the shown amounts are replaced with
  /// the server's and the banner is raised — the user must tap again; this
  /// never resubmits by itself.
  Future<bool> submit({
    required List<SettleAllLine> shown,
    SettlementMethod? method,
    String? notes,
  }) async {
    if (state.submitting) return false;
    state = SettleAllState(current: state.current, submitting: true);
    // Survive the screen closing mid-request so the outcome still lands.
    final link = ref.keepAlive();
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .settleAll(
            friendId: key.friendId,
            currency: key.currency,
            expected: shown,
            method: method,
            notes: notes,
          );
    } on SettleAllBalancesChanged catch (e) {
      // Refresh the friend + group balances behind this screen too.
      ref.invalidate(groupsProvider);
      for (final id in {...shown, ...e.current}.map((l) => l.groupId)) {
        ref.invalidate(groupDetailProvider(id));
      }
      state = SettleAllState(current: e.current, balancesChanged: true);
      return false;
    } on SettlementsApiException catch (e) {
      state = SettleAllState(current: state.current, error: e.message);
      return false;
    } catch (e) {
      state = SettleAllState(
        current: state.current,
        error: 'Could not record payment: $e',
      );
      return false;
    } finally {
      link.close();
    }

    ref.invalidate(groupsProvider); // friendsProvider refetches off this
    ref.invalidate(dashboardProvider);
    for (final l in shown) {
      ref.invalidate(groupDetailProvider(l.groupId));
    }
    // Stays "submitting" until the screen pops.
    return true;
  }

  /// Records a "Settle all" that was already paid by UPI ([paid] rupees).
  ///
  /// The money has moved, so unlike [submit] this must not end with "check
  /// the new total": if balances changed meanwhile (409), it records one
  /// ordinary payment of [paid] in the group where I owe the most instead —
  /// the per-group split may then differ, but the overall balance with the
  /// friend is right. Returns the snackbar text, or null on failure (the
  /// error is in the state).
  Future<String?> submitAfterUpi({
    required List<SettleAllLine> shown,
    required double paid,
    required String friendName,
    String? notes,
  }) async {
    if (await submit(
      shown: shown,
      method: SettlementMethod.upi,
      notes: notes,
    )) {
      return AppStrings.settledUpWithName(friendName);
    }
    if (!state.balancesChanged) return null;

    final me = ref.read(authProvider).user;
    final candidates = [...?state.current, ...shown];
    if (me == null || candidates.isEmpty) return null;
    final target = candidates.reduce((a, b) => b.amount > a.amount ? b : a);
    state = SettleAllState(current: state.current, submitting: true);
    final link = ref.keepAlive();
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .create(
            groupId: target.groupId,
            fromUserId: me.id,
            toUserId: key.friendId,
            amount: paid,
            currency: key.currency,
            notes: notes,
            method: SettlementMethod.upi,
          );
    } catch (e) {
      state = SettleAllState(
        current: state.current,
        balancesChanged: true,
        error: AppStrings.upiPaidNotRecorded('$e'),
      );
      return null;
    } finally {
      link.close();
    }
    ref.invalidate(groupsProvider);
    ref.invalidate(dashboardProvider);
    for (final l in candidates) {
      ref.invalidate(groupDetailProvider(l.groupId));
    }
    return AppStrings.upiRecordedInGroup(target.groupName);
  }
}
