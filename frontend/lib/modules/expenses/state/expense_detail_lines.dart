import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/models.dart';

/// Pure text for the per-person lines on the expense detail screen
/// ("Asha K. paid ₹600.00 and owes ₹400.00"). No widgets, no providers.

/// One person on the expense: what they paid and what their share is.
class ExpensePersonShare {
  const ExpensePersonShare({
    required this.userId,
    required this.name,
    required this.paid,
    required this.owes,
    this.split,
  });

  final String userId;

  /// As the server sent it (may be blank — the screen resolves names).
  final String name;
  final double paid;
  final double owes;

  /// Their split row, or null for a payer who isn't in the split.
  final SplitModel? split;
}

/// The expense's payers; one built from [ExpenseModel.paidBy] when the
/// list is empty (models built without `payers`).
List<ExpensePayer> expensePayersOf(ExpenseModel e) => e.payers.isNotEmpty
    ? e.payers
    : [
        ExpensePayer(
          userId: e.paidBy.id,
          name: e.paidBy.name,
          amount: e.amount,
        ),
      ];

/// Everyone on [expense]: payers first (biggest amount first), then the
/// rest in split order.
List<ExpensePersonShare> expensePeopleShares(ExpenseModel expense) {
  final splitById = {for (final s in expense.splits) s.userId: s};
  final payers = [...expensePayersOf(expense)]
    ..sort((a, b) => b.amount.compareTo(a.amount));
  double paidBy(String id) => payers
      .where((p) => p.userId == id)
      .fold<double>(0, (t, p) => t + p.amount);
  final seen = <String>{};
  final out = <ExpensePersonShare>[];
  for (final p in payers) {
    if (!seen.add(p.userId)) continue;
    final split = splitById[p.userId];
    out.add(
      ExpensePersonShare(
        userId: p.userId,
        name: p.name.trim().isNotEmpty ? p.name : (split?.userName ?? ''),
        paid: paidBy(p.userId),
        owes: split?.owedShare ?? 0,
        split: split,
      ),
    );
  }
  for (final s in expense.splits) {
    if (!seen.add(s.userId)) continue;
    out.add(
      ExpensePersonShare(
        userId: s.userId,
        name: s.userName,
        paid: 0,
        owes: s.owedShare,
        split: s,
      ),
    );
  }
  return out;
}

/// "Asha K. paid ₹600.00 and owes ₹400.00", "Ravi owes ₹200.00",
/// "Asha K. paid ₹1,000.00" — or, for [isYou], "You paid ₹400.00 and owe
/// ₹600.00" / "You owe ₹200.00" / "You paid ₹1,000.00". Amounts under half
/// a paisa count as nothing.
String expensePersonLine({
  required String name,
  required bool isYou,
  required double paid,
  required double owes,
  required String currency,
}) {
  String money(double v) => CurrencyFormatter.format(v, currency: currency);
  final hasPaid = paid > 0.004;
  final hasShare = owes > 0.004;
  if (isYou) {
    if (hasPaid && hasShare) {
      return AppStrings.youPaidAndOwe(money(paid), money(owes));
    }
    if (hasPaid) return AppStrings.youPaidAmount(money(paid));
    return AppStrings.youOweAmount(money(owes));
  }
  if (hasPaid && hasShare) {
    return AppStrings.personPaidAndOwes(name, money(paid), money(owes));
  }
  if (hasPaid) return AppStrings.personPaid(name, money(paid));
  return AppStrings.personOwes(name, money(owes));
}

/// "Equally", "By percentage", … — the split method note under the people.
String expenseSplitMethodLabel(ExpenseModel e) {
  if (e.isAdjustmentSplit) return AppStrings.splitAdjustment;
  switch (e.splitType) {
    case SplitType.equal:
      return AppStrings.splitEqually;
    case SplitType.exact:
      return AppStrings.splitExactAmounts;
    case SplitType.percentage:
      return AppStrings.splitPercentage;
    case SplitType.shares:
      return AppStrings.splitShares;
  }
}

/// "40% × ₹1,000.00 = ₹400.00" / "2 / 5 × ₹1,000.00 = ₹400.00" for the
/// "Show working" line of a percentage / shares split; null otherwise.
String? expenseWorkingLine({
  required SplitModel split,
  required SplitType splitType,
  required double totalAmount,
  required double totalShares,
  required String currency,
}) {
  String money(double v) => CurrencyFormatter.format(v, currency: currency);
  String trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  switch (splitType) {
    case SplitType.percentage:
      // Prefer the stored percentage; legacy rows derive it from the share.
      final p = split.percentage > 0
          ? split.percentage
          : (totalAmount > 0 ? split.owedShare / totalAmount * 100 : null);
      if (p == null) return null;
      return '${trim(p)}%  ×  ${money(totalAmount)}  =  '
          '${money(split.owedShare)}';
    case SplitType.shares:
      if (split.shares <= 0 || totalShares <= 0) return null;
      return '${trim(split.shares)} / ${trim(totalShares)}  ×  '
          '${money(totalAmount)}  =  ${money(split.owedShare)}';
    case SplitType.equal:
    case SplitType.exact:
      return null;
  }
}

/// Edited after it was added (server `updated_at` more than a minute after
/// `created_at`) — only then is the edit history worth fetching for the
/// "Updated by … on …" line.
bool expenseWasEdited(ExpenseModel e) {
  final updated = DateTime.tryParse(e.updatedAtRaw ?? '');
  if (updated == null) return false;
  return updated.difference(e.createdAt).inSeconds.abs() > 60;
}
