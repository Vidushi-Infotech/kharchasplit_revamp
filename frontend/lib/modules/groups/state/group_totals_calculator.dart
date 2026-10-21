import '../../../core/constants/app_strings.dart';
import '../../../models/category_model.dart';
import '../../../models/expense_model.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';

/// Pure maths behind the group "Totals" tab and the PDF statement. No
/// Flutter, no providers — everything is passed in (including `now`) so the
/// period boundaries are testable.
///
/// Rules, kept the same everywhere they are used:
/// * Periods are calendar ranges in LOCAL time, by expense date.
/// * Expenses still in the offline outbox (`syncState != null`) are left
///   out and only counted in [GroupTotals.pendingExcluded] — the server has
///   not accepted them yet, so they are not part of the group's history.
/// * Who paid comes from `payers` (multi-payer aware), never `paidBy`.
/// * Payments are settlements the ledger counts (`countsTowardBalance`,
///   i.e. status paid), by settlement date.
enum TotalsPeriod { thisMonth, lastMonth, thisYear, allTime }

/// Half-open local-time range `[start, end)`; null bounds are open.
class TotalsRange {
  const TotalsRange(this.start, this.end);
  final DateTime? start;
  final DateTime? end;

  bool contains(DateTime date) {
    final d = date.toLocal();
    if (start != null && d.isBefore(start!)) return false;
    if (end != null && !d.isBefore(end!)) return false;
    return true;
  }
}

TotalsRange totalsRange(TotalsPeriod period, DateTime now) {
  final n = now.toLocal();
  switch (period) {
    case TotalsPeriod.thisMonth:
      return TotalsRange(
        DateTime(n.year, n.month),
        DateTime(n.year, n.month + 1),
      );
    case TotalsPeriod.lastMonth:
      return TotalsRange(
        DateTime(n.year, n.month - 1),
        DateTime(n.year, n.month),
      );
    case TotalsPeriod.thisYear:
      return TotalsRange(DateTime(n.year), DateTime(n.year + 1));
    case TotalsPeriod.allTime:
      return const TotalsRange(null, null);
  }
}

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.fraction,
  });
  final CategoryModel category;
  final double amount;

  /// Share of the period's total spending, 0..1.
  final double fraction;
}

class MonthTotal {
  const MonthTotal({required this.month, required this.amount});

  /// First day of the month, local time.
  final DateTime month;
  final double amount;
}

class MemberTotal {
  const MemberTotal({
    required this.userId,
    required this.name,
    required this.paid,
    required this.share,
  });
  final String userId;
  final String name;
  final double paid;
  final double share;

  /// > 0 → paid more than their share in the period.
  double get net => paid - share;
}

class GroupTotals {
  const GroupTotals({
    required this.totalSpending,
    required this.youPaid,
    required this.yourShare,
    required this.paymentsMade,
    required this.paymentsReceived,
    required this.categories,
    required this.months,
    required this.members,
    required this.expenseCount,
    required this.pendingExcluded,
  });

  final double totalSpending;
  final double youPaid;
  final double yourShare;
  final double paymentsMade;
  final double paymentsReceived;

  /// Largest first.
  final List<CategoryTotal> categories;

  /// Oldest first; empty for single-month periods.
  final List<MonthTotal> months;

  /// Everyone who is a member or appears on an expense, biggest payer first.
  final List<MemberTotal> members;
  final int expenseCount;
  final int pendingExcluded;

  bool get hasActivity =>
      expenseCount > 0 || paymentsMade > 0 || paymentsReceived > 0;
}

/// Most month bars shown for "This year" / "All time".
const int maxTotalsMonths = 12;

GroupTotals computeGroupTotals({
  required List<ExpenseModel> expenses,
  required List<SettlementModel> settlements,
  required List<UserModel> members,
  required String? myId,
  required TotalsPeriod period,
  required DateTime now,
}) {
  final range = totalsRange(period, now);
  var total = 0.0, youPaid = 0.0, yourShare = 0.0;
  var count = 0, pending = 0;
  final byCategory = <String, double>{};
  final byMonth = <DateTime, double>{};
  final paid = <String, double>{};
  final share = <String, double>{};
  final names = <String, String>{for (final m in members) m.id: m.name};

  for (final e in expenses) {
    if (!range.contains(e.date)) continue;
    if (e.isPendingSync) {
      pending++;
      continue;
    }
    count++;
    total += e.amount;
    byCategory[e.category.id] = (byCategory[e.category.id] ?? 0) + e.amount;
    final local = e.date.toLocal();
    final month = DateTime(local.year, local.month);
    byMonth[month] = (byMonth[month] ?? 0) + e.amount;
    for (final p in e.payers) {
      paid[p.userId] = (paid[p.userId] ?? 0) + p.amount;
      names.putIfAbsent(p.userId, () => p.name);
      if (p.userId == myId) youPaid += p.amount;
    }
    for (final s in e.splits) {
      share[s.userId] = (share[s.userId] ?? 0) + s.owedShare;
      names.putIfAbsent(s.userId, () => s.userName);
      if (s.userId == myId) yourShare += s.owedShare;
    }
  }

  var made = 0.0, received = 0.0;
  for (final s in settlements) {
    if (!s.countsTowardBalance || !range.contains(s.date)) continue;
    if (s.fromUser.id == myId) made += s.amount;
    if (s.toUser.id == myId) received += s.amount;
  }

  final categories = [
    for (final entry in byCategory.entries)
      CategoryTotal(
        category: CategoryModel.fromId(entry.key) ?? CategoryModel.other,
        amount: entry.value,
        fraction: total > 0 ? entry.value / total : 0,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));

  final memberTotals =
      [
        for (final id in names.keys)
          MemberTotal(
            userId: id,
            // Invited members who haven't signed up have no name yet.
            name: names[id]!.trim().isEmpty ? AppStrings.invitedMember : names[id]!,
            paid: paid[id] ?? 0,
            share: share[id] ?? 0,
          ),
      ]..sort((a, b) {
        final byPaid = b.paid.compareTo(a.paid);
        return byPaid != 0
            ? byPaid
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  return GroupTotals(
    totalSpending: total,
    youPaid: youPaid,
    yourShare: yourShare,
    paymentsMade: made,
    paymentsReceived: received,
    categories: categories,
    months: _monthBars(period, now, byMonth),
    members: memberTotals,
    expenseCount: count,
    pendingExcluded: pending,
  );
}

/// One bar per month, zero-filled. This year: January up to this month.
/// All time: from the first month with spending up to this month, capped
/// at the last [maxTotalsMonths]. Single-month periods get none.
List<MonthTotal> _monthBars(
  TotalsPeriod period,
  DateTime now,
  Map<DateTime, double> byMonth,
) {
  final n = now.toLocal();
  final last = DateTime(n.year, n.month);
  DateTime first;
  switch (period) {
    case TotalsPeriod.thisMonth:
    case TotalsPeriod.lastMonth:
      return const [];
    case TotalsPeriod.thisYear:
      first = DateTime(n.year);
    case TotalsPeriod.allTime:
      if (byMonth.isEmpty) return const [];
      first = byMonth.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      final cap = DateTime(last.year, last.month - (maxTotalsMonths - 1));
      if (first.isBefore(cap)) first = cap;
  }
  return [
    for (var m = first; !m.isAfter(last); m = DateTime(m.year, m.month + 1))
      MonthTotal(month: m, amount: byMonth[m] ?? 0),
  ];
}
