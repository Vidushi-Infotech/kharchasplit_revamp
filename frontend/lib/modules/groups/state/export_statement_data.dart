import '../../../core/constants/app_strings.dart';
import '../../../models/expense_model.dart';
import '../../../models/group_model.dart';
import '../../../models/settlement_model.dart';
import 'group_detail_provider.dart';
import 'group_totals_calculator.dart';

/// Everything the PDF group statement prints, as plain data. Built on the
/// UI isolate (cheap), rendered to PDF in a background isolate, and
/// unit-tested without touching the PDF layer.
///
/// Balances are ALWAYS as of today (all time) — a balance "for last month"
/// would not be what anyone owes. Only the expense list and the totals
/// follow the chosen period.
///
/// Who owes whom:
/// * group with "Simplify group debts" on → the server's simplified
///   transfers, the same numbers the Balances tab shows;
/// * otherwise → raw pairwise debts from [computePairwiseDebts] (the
///   Balances tab's helper), one line per pair, from the debtor's side.
/// Per-member net = paid − share + payments sent − payments received; it is
/// the same in both modes, so the two lists always agree.
///
/// Offline-pending expenses are excluded everywhere (same rule as Totals).
class GroupStatement {
  const GroupStatement({
    required this.groupName,
    required this.currencyCode,
    required this.periodLabel,
    required this.generatedAt,
    required this.totalSpending,
    required this.expenses,
    required this.balances,
    required this.debts,
    required this.simplified,
    required this.pendingExcluded,
  });

  final String groupName;

  /// ISO code (INR, USD…). The PDF's built-in font has no ₹ glyph, so
  /// amounts print as "INR 1,200.00".
  final String currencyCode;
  final String periodLabel;
  final DateTime generatedAt;
  final double totalSpending;

  /// Oldest first.
  final List<StatementExpenseRow> expenses;

  /// Everyone with a balance or a member of the group, largest credit first.
  final List<StatementBalanceRow> balances;
  final List<StatementDebt> debts;
  final bool simplified;
  final int pendingExcluded;
}

class StatementExpenseRow {
  const StatementExpenseRow({
    required this.date,
    required this.description,
    required this.paidBy,
    required this.amount,
  });
  final DateTime date;
  final String description;
  final String paidBy;
  final double amount;
}

class StatementBalanceRow {
  const StatementBalanceRow({required this.name, required this.net});
  final String name;

  /// > 0 → is owed this much overall; < 0 → owes.
  final double net;
}

class StatementDebt {
  const StatementDebt({
    required this.from,
    required this.to,
    required this.amount,
  });
  final String from;
  final String to;
  final double amount;
}

const _settledEpsilon = 0.01;

String statementCurrencyCode(String currency) => switch (currency) {
  '₹' => 'INR',
  '\$' => 'USD',
  '€' => 'EUR',
  '£' => 'GBP',
  _ => currency.toUpperCase(),
};

GroupStatement buildGroupStatement({
  required GroupDetail detail,
  required TotalsPeriod period,
  required String periodLabel,
  required DateTime now,
}) {
  final range = totalsRange(period, now);
  final synced = detail.expenses.where((e) => !e.isPendingSync).toList();
  final names = _names(detail, synced);

  final inPeriod = synced.where((e) => range.contains(e.date)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final rows = [
    for (final e in inPeriod)
      StatementExpenseRow(
        date: e.date.toLocal(),
        description: e.title,
        paidBy: e.payers.map((p) => names[p.userId] ?? p.name).join(', '),
        amount: e.amount,
      ),
  ];

  return GroupStatement(
    groupName: detail.group.name,
    currencyCode: statementCurrencyCode(detail.group.currency),
    periodLabel: periodLabel,
    generatedAt: now,
    totalSpending: inPeriod.fold(0, (s, e) => s + e.amount),
    expenses: rows,
    balances: _balances(synced, detail.settlements, names),
    debts: _debts(detail.group, synced, detail.settlements, names),
    simplified: detail.group.simplifyDebts,
    pendingExcluded: detail.expenses.length - synced.length,
  );
}

Map<String, String> _names(GroupDetail detail, List<ExpenseModel> expenses) {
  final names = <String, String>{for (final m in detail.members) m.id: m.name};
  for (final e in expenses) {
    for (final p in e.payers) {
      names.putIfAbsent(p.userId, () => p.name);
    }
    for (final s in e.splits) {
      names.putIfAbsent(s.userId, () => s.userName);
    }
  }
  for (final s in detail.settlements) {
    names.putIfAbsent(s.fromUser.id, () => s.fromUser.name);
    names.putIfAbsent(s.toUser.id, () => s.toUser.name);
  }
  // Invited members who haven't signed up have no name yet.
  return names.map((k, v) => MapEntry(k, v.trim().isEmpty ? AppStrings.invitedMember : v));
}

List<StatementBalanceRow> _balances(
  List<ExpenseModel> expenses,
  List<SettlementModel> settlements,
  Map<String, String> names,
) {
  final net = <String, double>{for (final id in names.keys) id: 0};
  for (final e in expenses) {
    for (final p in e.payers) {
      net[p.userId] = (net[p.userId] ?? 0) + p.amount;
    }
    for (final s in e.splits) {
      net[s.userId] = (net[s.userId] ?? 0) - s.owedShare;
    }
  }
  for (final s in settlements) {
    if (!s.countsTowardBalance) continue;
    net[s.fromUser.id] = (net[s.fromUser.id] ?? 0) + s.amount;
    net[s.toUser.id] = (net[s.toUser.id] ?? 0) - s.amount;
  }
  return [
    for (final entry in net.entries)
      StatementBalanceRow(
        name: names[entry.key] ?? entry.key,
        // Snap float dust to an exact 0 so "settled" prints as such.
        net: entry.value.abs() < _settledEpsilon ? 0 : entry.value,
      ),
  ]..sort((a, b) => b.net.compareTo(a.net));
}

List<StatementDebt> _debts(
  GroupModel group,
  List<ExpenseModel> expenses,
  List<SettlementModel> settlements,
  Map<String, String> names,
) {
  String name(String id) => names[id] ?? id;
  final debts = <StatementDebt>[];
  if (group.simplifyDebts) {
    for (final t in group.simplifiedTransfers) {
      if (t.amount < _settledEpsilon) continue;
      debts.add(
        StatementDebt(
          from: name(t.fromUserId),
          to: name(t.toUserId),
          amount: t.amount,
        ),
      );
    }
  } else {
    for (final id in names.keys) {
      final pair = computePairwiseDebts(
        myId: id,
        expenses: expenses,
        settlements: settlements,
      );
      pair.forEach((other, owed) {
        // > 0 → `id` owes `other`; the creditor's side is skipped.
        if (owed > _settledEpsilon) {
          debts.add(
            StatementDebt(from: name(id), to: name(other), amount: owed),
          );
        }
      });
    }
  }
  return debts..sort((a, b) => b.amount.compareTo(a.amount));
}
