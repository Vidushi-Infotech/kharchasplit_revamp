import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/list/balance_tone.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/expense_model.dart';
import '../../../models/settlement_model.dart';
import 'group_detail_provider.dart';

/// One row of the group detail list: a month header, an expense, or a
/// payment (settlement). Expenses and payments share one date-sorted list,
/// the way Splitwise shows a group.
sealed class GroupLedgerItem {
  const GroupLedgerItem();
}

class LedgerMonthHeader extends GroupLedgerItem {
  const LedgerMonthHeader(this.month);

  /// First day of the month, local time.
  final DateTime month;
}

class LedgerExpense extends GroupLedgerItem {
  const LedgerExpense(this.expense);
  final ExpenseModel expense;
}

class LedgerPayment extends GroupLedgerItem {
  const LedgerPayment(this.settlement);
  final SettlementModel settlement;
}

/// Newest first, with a [LedgerMonthHeader] before each month's rows. Ties
/// on the date fall back to creation time so a just-added row sits on top.
List<GroupLedgerItem> buildGroupLedger({
  required List<ExpenseModel> expenses,
  required List<SettlementModel> settlements,
}) {
  final rows = <({DateTime date, DateTime created, GroupLedgerItem item})>[
    for (final e in expenses)
      (date: e.date.toLocal(), created: e.createdAt, item: LedgerExpense(e)),
    for (final s in settlements)
      (date: s.date.toLocal(), created: s.createdAt, item: LedgerPayment(s)),
  ];
  rows.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.created.compareTo(a.created);
  });

  final out = <GroupLedgerItem>[];
  DateTime? month;
  for (final r in rows) {
    final m = DateTime(r.date.year, r.date.month);
    if (month != m) {
      out.add(LedgerMonthHeader(m));
      month = m;
    }
    out.add(r.item);
  }
  return out;
}

/// The group's ledger rows from the loaded detail (null while loading).
final groupLedgerProvider = Provider.autoDispose
    .family<List<GroupLedgerItem>?, String>((ref, groupId) {
      final detail = ref.watch(groupDetailProvider(groupId)).value;
      if (detail == null) return null;
      return buildGroupLedger(
        expenses: detail.expenses,
        settlements: detail.settlements,
      );
    });

/// How an expense row reads for the viewer: one [tone] drives both the
/// label and the amount color, so they can never disagree.
class ExpenseRowView {
  const ExpenseRowView({
    required this.tone,
    required this.amount,
    required this.payerLine,
  });

  /// owed = you lent, owe = you borrowed, settled = involved but even,
  /// notInvolved = neither paid nor in the split.
  final BalanceTone tone;

  /// What you lent / borrowed on this expense (always ≥ 0).
  final double amount;

  /// "Test R. paid ₹1,000.00", "You paid ₹1,000.00", "2 people paid …".
  final String payerLine;
}

/// The viewer's net on [expense]: the same per-payer flows the group
/// ledger uses ([computePairwiseDebts]), so multi-payer expenses and
/// shares that don't add up to the amount match the Balances screen.
ExpenseRowView expenseRowView(ExpenseModel expense, String? myId) {
  final payerLine = _payerLine(expense, myId);
  final involved =
      myId != null &&
      (expense.isPayer(myId) || expense.splits.any((s) => s.userId == myId));
  if (!involved) {
    return ExpenseRowView(
      tone: BalanceTone.notInvolved,
      amount: 0,
      payerLine: payerLine,
    );
  }
  // pair > 0 = I owe that person on this expense, < 0 = they owe me.
  final pair = computePairwiseDebts(
    myId: myId,
    expenses: [expense],
    settlements: const [],
  );
  final net = -pair.values.sum;
  return ExpenseRowView(
    tone: BalanceTone.fromAmount(net),
    amount: net.abs(),
    payerLine: payerLine,
  );
}

String _payerLine(ExpenseModel e, String? myId) {
  final amount = CurrencyFormatter.format(e.amount, currency: e.currency);
  final payers = e.payers.where((p) => p.amount > 0).toList();
  if (payers.length > 1) {
    return '${AppStrings.peoplePaid(payers.length)} $amount';
  }
  final id = payers.isEmpty ? e.paidBy.id : payers.first.userId;
  final name = payers.isEmpty ? e.paidBy.name : payers.first.name;
  if (id == myId) return AppStrings.youPaidAmount(amount);
  return AppStrings.namePaid(NameFormat.short(name), amount);
}

/// "Test F. paid you ₹200.00" / "You paid Test F. ₹200.00" /
/// "Test F. paid Test R. ₹200.00".
String paymentRowTitle(SettlementModel s, String? myId) {
  final amount = CurrencyFormatter.format(s.amount, currency: s.currency);
  // Invited people may have no name yet.
  String name(String n) =>
      n.trim().isEmpty ? AppStrings.invitedMember : NameFormat.short(n);
  final from = name(s.fromUser.name);
  final to = name(s.toUser.name);
  if (s.fromUser.id == myId) return AppStrings.youPaidNameAmount(to, amount);
  if (s.toUser.id == myId) return AppStrings.namePaidYou(from, amount);
  return AppStrings.namePaidName(from, to, amount);
}

/// Grey status under a payment that doesn't (yet) count, else null.
String? paymentRowStatus(SettlementModel s) => switch (s.status) {
  SettlementStatus.pending => AppStrings.paymentAwaitingConfirmation,
  SettlementStatus.failed => AppStrings.paymentNotReceived,
  SettlementStatus.completed => null,
};
