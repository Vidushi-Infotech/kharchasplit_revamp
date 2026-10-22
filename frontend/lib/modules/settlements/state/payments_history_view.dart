import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/list/balance_tone.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_balance_helpers.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/group_display.dart';

/// Under this a balance counts as settled (same as the Balances screen).
const double _settledEpsilon = 0.01;

/// Everything the Payments page shows for the viewer and one other person
/// in one group: the balance between them (the group's own numbers, so it
/// always matches group detail) and every payment between the two.
class PaymentsHistoryView {
  const PaymentsHistoryView({
    required this.me,
    required this.other,
    required this.otherName,
    required this.otherIsMember,
    required this.groupName,
    required this.isDirect,
    required this.currency,
    required this.balance,
    required this.pendingFromMe,
    required this.pendingFromThem,
    required this.payments,
  });

  final UserModel? me;
  final UserModel other;

  /// Full name, never blank: current member, then a name found on the
  /// group's expenses / payments, then "Invited member".
  final String otherName;

  /// False when they left (or were removed from) the group.
  final bool otherIsMember;
  final String groupName;
  final bool isDirect;
  final String currency;

  /// > 0 → they owe you; < 0 → you owe them. Same source as the group
  /// header and Balances ([groupVisibleDebts]).
  final double balance;

  /// Unconfirmed payments in each direction (don't move [balance] yet).
  final double pendingFromMe;
  final double pendingFromThem;

  /// Newest first.
  final List<SettlementModel> payments;

  String get shortName => NameFormat.short(otherName);

  BalanceTone get tone => balance.abs() <= _settledEpsilon
      ? BalanceTone.settled
      : BalanceTone.fromAmount(balance);

  /// What Settle up should ask for: your debt minus what's already in a
  /// pending payment to them. 0 when they owe you or it's all covered.
  double get toSettle {
    if (tone != BalanceTone.owe) return 0;
    final left = -balance - pendingFromMe;
    return left > _settledEpsilon ? left : 0;
  }
}

/// Builds the view from a loaded group. [myId] null → no balance or
/// payments (signed out).
PaymentsHistoryView buildPaymentsHistoryView({
  required GroupDetail detail,
  required String? myId,
  required String otherId,
}) {
  final member = detail.members.firstWhereOrNull((m) => m.id == otherId);
  final name = resolvePersonName(otherId, detail);
  final other = member ?? _knownUser(otherId, name, detail);
  final payments = myId == null
      ? <SettlementModel>[]
      : (detail.settlements
            .where(
              (s) =>
                  (s.fromUser.id == myId && s.toUser.id == otherId) ||
                  (s.fromUser.id == otherId && s.toUser.id == myId),
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
          }));
  double pending({required bool fromMe}) => payments
      .where(
        (s) =>
            s.status == SettlementStatus.pending &&
            (s.fromUser.id == myId) == fromMe,
      )
      .fold(0, (sum, s) => sum + s.amount);
  // pair > 0 → I owe them; flip so a positive balance means they owe me.
  final pair = myId == null
      ? const <String, double>{}
      : groupVisibleDebts(myId: myId, detail: detail);
  return PaymentsHistoryView(
    me: detail.members.firstWhereOrNull((m) => m.id == myId),
    other: other,
    otherName: name,
    otherIsMember: member != null,
    groupName: detail.group.displayTitle(myId),
    isDirect: detail.group.isDirect,
    currency: detail.group.currency,
    balance: -(pair[otherId] ?? 0),
    pendingFromMe: pending(fromMe: true),
    pendingFromThem: pending(fromMe: false),
    payments: payments,
  );
}

/// A person's name in this group even after they left: current members
/// first, then the names stored on the group's expenses and payments.
/// Falls back to "Invited member" (never "Member" / "them").
String resolvePersonName(String id, GroupDetail detail) {
  bool ok(String n) => n.trim().isNotEmpty && n.trim() != 'Unknown';
  final member = detail.members.firstWhereOrNull((m) => m.id == id);
  if (member != null && ok(member.name)) return member.name.trim();
  for (final e in detail.expenses) {
    if (e.paidBy.id == id && ok(e.paidBy.name)) return e.paidBy.name.trim();
    for (final p in e.payers) {
      if (p.userId == id && ok(p.name)) return p.name.trim();
    }
    for (final s in e.splits) {
      if (s.userId == id && ok(s.userName)) return s.userName.trim();
    }
  }
  for (final s in detail.settlements) {
    for (final u in [s.fromUser, s.toUser]) {
      if (u.id == id && ok(u.name)) return u.name.trim();
    }
  }
  return AppStrings.invitedMember;
}

/// A former member as a [UserModel], keeping the avatar a payment carried.
UserModel _knownUser(String id, String name, GroupDetail detail) {
  final fromPayment = detail.settlements
      .expand((s) => [s.fromUser, s.toUser])
      .firstWhereOrNull((u) => u.id == id);
  return UserModel(
    id: id,
    name: name,
    email: '',
    phone: '',
    avatarUrl: fromPayment?.avatarUrl,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// The line under the avatars: "Test F. owes you ₹200.00 in Goa trip",
/// "You owe Test F. …", or "You and Test F. are settled up …". A direct
/// (non-group) pair leaves the group name out.
String paymentsHeaderLine(PaymentsHistoryView v) {
  final amount = CurrencyFormatter.format(
    v.balance.abs(),
    currency: v.currency,
  );
  final name = v.shortName;
  return switch (v.tone) {
    BalanceTone.owed =>
      v.isDirect
          ? AppStrings.nameOwesYou(name, amount)
          : AppStrings.historyOwesYouIn(name, amount, v.groupName),
    BalanceTone.owe =>
      v.isDirect
          ? AppStrings.youOweName(name, amount)
          : AppStrings.historyYouOweIn(name, amount, v.groupName),
    _ =>
      v.isDirect
          ? AppStrings.historySettledWith(name)
          : AppStrings.historySettledIn(name, v.groupName),
  };
}

/// Gray lines under the header about payments still waiting on someone.
List<String> paymentsPendingLines(PaymentsHistoryView v) {
  String fmt(double a) => CurrencyFormatter.format(a, currency: v.currency);
  return [
    if (v.pendingFromMe > _settledEpsilon)
      AppStrings.historyPendingFromMe(fmt(v.pendingFromMe), v.shortName),
    if (v.pendingFromThem > _settledEpsilon)
      AppStrings.historyPendingFromThem(v.shortName, fmt(v.pendingFromThem)),
    if (v.tone == BalanceTone.owe &&
        v.toSettle == 0 &&
        v.pendingFromMe > _settledEpsilon)
      AppStrings.historyCoveredByPending,
  ];
}

/// The Payments page for (group, other person); null while the group loads.
final paymentsHistoryProvider = Provider.autoDispose
    .family<PaymentsHistoryView?, ({String groupId, String otherId})>((
      ref,
      key,
    ) {
      final detail = ref.watch(groupDetailProvider(key.groupId)).value;
      if (detail == null) return null;
      return buildPaymentsHistoryView(
        detail: detail,
        myId: ref.watch(myIdProvider),
        otherId: key.otherId,
      );
    });
