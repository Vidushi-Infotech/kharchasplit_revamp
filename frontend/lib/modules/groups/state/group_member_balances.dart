import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import 'group_balance_helpers.dart';
import 'group_detail_provider.dart';

/// Under this a balance counts as settled (same threshold as the old
/// balance cards).
const double _settledEpsilon = 0.01;

/// One "who owes whom" line under a member on the Balances screen.
class MemberBalanceLine {
  const MemberBalanceLine({required this.other, required this.amount});

  final UserModel other;

  /// > 0 → the row's member owes [other]; < 0 → [other] owes them.
  final double amount;
}

/// A member's total balance in the group plus the pairwise lines behind it.
class MemberBalance {
  const MemberBalance({
    required this.member,
    required this.net,
    required this.lines,
  });

  final UserModel member;

  /// > 0 → gets back in total; < 0 → owes in total.
  final double net;

  /// Largest first; empty when settled up.
  final List<MemberBalanceLine> lines;

  bool get settled => net.abs() <= _settledEpsilon && lines.isEmpty;
}

/// Every member's balance, using the debts the group shows
/// ([groupVisibleDebts] — simplified transfers when "Simplify group debts"
/// is on). The viewer comes first, then the biggest balances, settled
/// members last.
List<MemberBalance> buildMemberBalances(GroupDetail detail, String? myId) {
  final byId = {for (final m in detail.members) m.id: m};
  UserModel person(String id) => byId[id] ?? _formerMember(id, detail);
  final out = <MemberBalance>[];
  // Current members, then anyone who left but still has a balance.
  final ids = [for (final m in detail.members) m.id];
  for (var i = 0; i < ids.length; i++) {
    final pair = groupVisibleDebts(myId: ids[i], detail: detail);
    final lines = <MemberBalanceLine>[
      for (final e in pair.entries)
        if (e.value.abs() > _settledEpsilon)
          MemberBalanceLine(other: person(e.key), amount: e.value),
    ]..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    for (final l in lines) {
      if (!ids.contains(l.other.id)) ids.add(l.other.id);
    }
    out.add(MemberBalance(
      member: person(ids[i]),
      net: -pair.values.sum,
      lines: lines,
    ));
  }
  out.sort((a, b) {
    if (a.member.id == myId) return -1;
    if (b.member.id == myId) return 1;
    if (a.settled != b.settled) return a.settled ? 1 : -1;
    return b.net.abs().compareTo(a.net.abs());
  });
  return out;
}

/// Released with the Balances screen; recomputed from the loaded detail.
final groupMemberBalancesProvider = Provider.autoDispose
    .family<List<MemberBalance>?, String>((ref, groupId) {
      final detail = ref.watch(groupDetailProvider(groupId)).value;
      if (detail == null) return null;
      return buildMemberBalances(detail, ref.watch(myIdProvider));
    });

/// The viewer's side of the group for the detail header: overall [net]
/// (> 0 = you are owed) and one line per person you have a balance with.
class GroupViewerSummary {
  const GroupViewerSummary({required this.net, required this.lines});

  final double net;

  /// amount > 0 → they owe you; < 0 → you owe them. Largest first.
  final List<MemberBalanceLine> lines;

  /// The people you owe (amount < 0), largest first.
  Iterable<MemberBalanceLine> get youOwe => lines.where((l) => l.amount < 0);
}

GroupViewerSummary buildViewerSummary(GroupDetail detail, String? myId) {
  if (myId == null) return const GroupViewerSummary(net: 0, lines: []);
  final byId = {for (final m in detail.members) m.id: m};
  // pair > 0 → I owe them; flip so a positive line means they owe me.
  final pair = groupVisibleDebts(myId: myId, detail: detail);
  final lines = <MemberBalanceLine>[
    for (final e in pair.entries)
      if (e.value.abs() > _settledEpsilon)
        MemberBalanceLine(
          other: byId[e.key] ?? _formerMember(e.key, detail),
          amount: -e.value,
        ),
  ]..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
  return GroupViewerSummary(net: -pair.values.sum, lines: lines);
}

/// Someone who left the group but still has a balance on old expenses.
/// Their name is taken from those expenses or payments when we have it
/// (empty → the header says "Former member").
UserModel _formerMember(String id, GroupDetail detail) => UserModel(
  id: id,
  name: _knownName(id, detail),
  email: '',
  phone: '',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

String _knownName(String id, GroupDetail detail) {
  for (final e in detail.expenses) {
    if (e.paidBy.id == id && e.paidBy.name.trim().isNotEmpty) {
      return e.paidBy.name;
    }
    for (final p in e.payers) {
      if (p.userId == id && p.name.trim().isNotEmpty) return p.name;
    }
    for (final s in e.splits) {
      if (s.userId == id && s.userName.trim().isNotEmpty) return s.userName;
    }
  }
  for (final s in detail.settlements) {
    for (final u in [s.fromUser, s.toUser]) {
      if (u.id == id && u.name.trim().isNotEmpty) return u.name;
    }
  }
  return '';
}

/// Only the creator of a normal group is its admin; a direct (two-person)
/// group has none, so no admin action is offered there.
bool isGroupAdmin(GroupDetail detail, String? myId) =>
    myId != null && !detail.group.isDirect && detail.group.createdBy == myId;

/// The one person Settle up should go straight to: when the viewer owes
/// exactly one member, that member and the amount not already in a pending
/// payment. Null otherwise (nobody, or several — Balances lets them pick).
({String userId, double amount})? singleSettleTarget(
  GroupDetail detail,
  String? myId,
) {
  if (myId == null) return null;
  final owe = buildViewerSummary(detail, myId).youOwe.toList();
  if (owe.length != 1) return null;
  final debt = -owe.single.amount;
  final pending = computePendingOutgoing(
    myId: myId,
    settlements: detail.settlements,
  )[owe.single.other.id];
  final left = debt - (pending ?? 0);
  if (left <= _settledEpsilon) return null;
  return (userId: owe.single.other.id, amount: left);
}
