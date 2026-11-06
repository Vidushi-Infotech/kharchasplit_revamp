import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/group_model.dart';
import '../../friends/state/friends_provider.dart';

/// Filter menu on the Groups tab.
enum GroupsListFilter { all, outstanding, youOwe, oweYou }

final groupsListFilterProvider =
    NotifierProvider<GroupsListFilterNotifier, GroupsListFilter>(
      GroupsListFilterNotifier.new,
    );

class GroupsListFilterNotifier extends Notifier<GroupsListFilter> {
  @override
  GroupsListFilter build() => GroupsListFilter.all;

  void set(GroupsListFilter value) => state = value;
}

/// Whether the archived groups are listed under the active ones.
final showArchivedGroupsProvider =
    NotifierProvider<ShowArchivedGroupsNotifier, bool>(
      ShowArchivedGroupsNotifier.new,
    );

class ShowArchivedGroupsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Balances below this are rounding noise, not money.
const double _epsilon = 0.005;

/// Groups matching [filter], by the signed balance shown on each row.
List<GroupModel> filterGroups(
  Iterable<GroupModel> groups,
  GroupsListFilter filter,
) => groups.where((g) {
  final b = g.myBalance;
  return switch (filter) {
    GroupsListFilter.all => true,
    GroupsListFilter.outstanding => b.abs() > _epsilon,
    GroupsListFilter.youOwe => b < -_epsilon,
    GroupsListFilter.oweYou => b > _epsilon,
  };
}).toList();

/// One person's open balance with you inside one group.
class GroupPersonBalance {
  const GroupPersonBalance({
    required this.name,
    required this.net,
    required this.currency,
  });

  final String name;

  /// Positive = they owe you; negative = you owe them.
  final double net;

  /// ISO code, e.g. `INR`.
  final String currency;
}

/// Per-group, per-person balances, regrouped from the friends ledger
/// (GET /users/:id/friends `groups[]`) — data the app already has, so the
/// Groups rows need no extra request. Largest balance first.
final groupPersonBalancesProvider =
    Provider<Map<String, List<GroupPersonBalance>>>((ref) {
      final friends = ref.watch(friendsProvider).value ?? const [];
      return groupPersonBalancesFrom(friends);
    });

/// Pure part of [groupPersonBalancesProvider].
Map<String, List<GroupPersonBalance>> groupPersonBalancesFrom(
  List<FriendBalance> friends,
) {
  final out = <String, List<GroupPersonBalance>>{};
  for (final f in friends) {
    for (final g in f.groups) {
      if (g.net.abs() <= _epsilon) continue;
      out
          .putIfAbsent(g.groupId, () => [])
          .add(
            GroupPersonBalance(
              name: f.user.name,
              net: g.net,
              currency: g.currency,
            ),
          );
    }
  }
  for (final list in out.values) {
    list.sort((a, b) => b.net.abs().compareTo(a.net.abs()));
  }
  return out;
}

/// Gray lines under a group's name: up to two "Test F. owes you ₹200" /
/// "You owe Test R. ₹50", then "Plus N more balances". Empty when the
/// group is settled — and for groups with simplify debts on, whose
/// settle-up plan differs from the pairwise ledger (the trailing amount
/// still shows the total).
List<String> groupBalanceLines(
  GroupModel group,
  List<GroupPersonBalance> people,
) {
  if (group.simplifyDebts || people.isEmpty) return const [];
  final lines = <String>[
    for (final p in people.take(2))
      p.net > 0
          ? AppStrings.nameOwesYou(
              NameFormat.short(p.name),
              CurrencyFormatter.format(p.net.abs(), currency: p.currency),
            )
          : AppStrings.youOweName(
              NameFormat.short(p.name),
              CurrencyFormatter.format(p.net.abs(), currency: p.currency),
            ),
  ];
  if (people.length > 2) {
    lines.add(AppStrings.plusMoreBalances(people.length - 2));
  }
  return lines;
}
