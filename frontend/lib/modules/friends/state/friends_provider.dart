import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/friends/friends_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/groups_provider.dart';

export '../../../data/friends/friends_repository.dart'
    show FriendBalance, FriendGroupBalance;

/// Everyone the signed-in user shares a group with (or still has an open
/// balance with), with balances from the server ledger — the same numbers as
/// each group's Balances tab. Open balances first, then by name.
///
/// Watches `groupsProvider.future` so the list refetches whenever the groups
/// list is invalidated — that already happens after expenses, settlements
/// and push refreshes, so friend balances follow without extra wiring.
final friendsProvider = FutureProvider<List<FriendBalance>>((ref) async {
  final myId = ref.watch(authProvider.select((s) => s.user?.id));
  try {
    await ref.watch(groupsProvider.future);
  } catch (_) {
    // A failed groups fetch shouldn't hide friends; we only use it as a
    // refresh trigger.
  }
  if (myId == null) return const <FriendBalance>[];
  return ref.read(friendsRepositoryProvider).list(myId);
});

/// One friend by id from [friendsProvider]. `null` data = not a friend
/// (e.g. a stale deep link) — the detail screen shows a not-found state.
final friendByIdProvider =
    Provider.family<AsyncValue<FriendBalance?>, String>((ref, friendId) {
  return ref.watch(friendsProvider).whenData(
        (list) => list.firstWhereOrNull((f) => f.user.id == friendId),
      );
});

/// "Hide settled-up friends" toggle on the Friends list.
final hideSettledFriendsProvider =
    NotifierProvider<HideSettledFriendsNotifier, bool>(
  HideSettledFriendsNotifier.new,
);

class HideSettledFriendsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Friends list after the hide-settled filter.
final visibleFriendsProvider = Provider<AsyncValue<List<FriendBalance>>>((ref) {
  final hideSettled = ref.watch(hideSettledFriendsProvider);
  return ref.watch(friendsProvider).whenData(
        (list) => hideSettled
            ? list.where((f) => !f.isSettled).toList()
            : list,
      );
});

/// Overall balance per currency code across all friends (positive = you
/// are owed). Currencies are never converted, so a mixed list yields one
/// entry per currency; zero totals are dropped (empty map = all settled).
final friendsTotalsProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  return ref.watch(friendsProvider).whenData((list) {
    final totals = <String, double>{};
    for (final f in list) {
      f.netByCurrency.forEach((cur, net) {
        totals[cur] = (totals[cur] ?? 0) + net;
      });
    }
    totals.removeWhere((_, v) => v.abs() < 0.005);
    return totals;
  });
});

extension FriendBalanceX on FriendBalance {
  /// Net per currency, from the per-group rows. Falls back to the overall
  /// net in INR when the server sent no group rows but a non-zero net.
  Map<String, double> get netByCurrency {
    if (groups.isEmpty) {
      return isSettled ? const {} : {'INR': net};
    }
    final out = <String, double>{};
    for (final g in groups) {
      out[g.currency] = (out[g.currency] ?? 0) + g.net;
    }
    out.removeWhere((_, v) => v.abs() < 0.005);
    return out;
  }

  /// Groups where you owe this friend (settle-up candidates).
  List<FriendGroupBalance> get groupsYouOwe =>
      groups.where((g) => g.net < -0.005).toList();

  /// Groups where this friend owes you (remind candidates).
  List<FriendGroupBalance> get groupsOwingYou =>
      groups.where((g) => g.net > 0.005).toList();

  /// Currencies where "Settle all balances" applies: you owe this friend
  /// overall in that currency, across two or more groups (with one group,
  /// the per-group Settle up is the same payment).
  List<String> get settleAllCurrencies => [
        for (final e in netByCurrency.entries)
          if (e.value < -0.005 &&
              groups
                      .where((g) => g.currency == e.key && g.net.abs() > 0.005)
                      .length >=
                  2)
            e.key,
      ];
}
