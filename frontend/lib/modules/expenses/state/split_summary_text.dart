import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/split_calculator.dart';
import 'add_expense_split_math.dart';

/// Bottom bar of the Split options screen: [main] ("₹500.00/person",
/// "₹300.00 of ₹500.00", "60% of 100%") and an optional [detail]
/// ("(2 people)", "₹200.00 left", "₹20.00 over"). [balanced] = the split
/// adds up (drives the color).
class SplitSummary {
  const SplitSummary({required this.main, this.detail, required this.balanced});

  final String main;
  final String? detail;
  final bool balanced;

  /// One line, e.g. "₹500.00/person (2 people)".
  String get text => detail == null ? main : '$main $detail';
}

String _pct(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.toInt()}%' : '${r.toStringAsFixed(1)}%';
}

/// [assigned] = the included people's entered values: rupees for exact,
/// percent for percentage, shares for shares (unused for equal and
/// adjustment). [people] = how many are in the split.
SplitSummary splitOptionsSummary({
  required AddExpenseSplitMode mode,
  required double amount,
  required String currency,
  required int people,
  double assigned = 0,
}) {
  String money(double v) => CurrencyFormatter.format(v, currency: currency);
  if (people <= 0) {
    return const SplitSummary(
      main: AppStrings.selectAtLeastOne,
      balanced: false,
    );
  }
  switch (mode) {
    case AddExpenseSplitMode.equal:
      return SplitSummary(
        main: AppStrings.perPerson(money(amount / people)),
        detail: AppStrings.peopleInSplit(people),
        balanced: true,
      );
    case AddExpenseSplitMode.exact:
      // Exact to the paisa, like the validation.
      final left =
          SplitCalculator.toPaise(amount) - SplitCalculator.toPaise(assigned);
      return SplitSummary(
        main: AppStrings.amountOfTotal(money(assigned), money(amount)),
        detail: left >= 0
            ? AppStrings.amountLeft(money(left / 100))
            : AppStrings.amountOverShort(money(-left / 100)),
        balanced: left == 0,
      );
    case AddExpenseSplitMode.percentage:
      final left = 100 - assigned;
      return SplitSummary(
        main: AppStrings.amountOfTotal(_pct(assigned), '100%'),
        detail: left >= -0.005
            ? AppStrings.amountLeft(_pct(left.abs()))
            : AppStrings.amountOverShort(_pct(-left)),
        balanced: left.abs() < 0.01,
      );
    case AddExpenseSplitMode.shares:
      final n = assigned == assigned.roundToDouble()
          ? assigned.toInt().toString()
          : assigned.toStringAsFixed(1);
      return SplitSummary(
        main: AppStrings.totalShares(n),
        detail: AppStrings.peopleInSplit(people),
        balanced: assigned > 0,
      );
    case AddExpenseSplitMode.adjustment:
      return SplitSummary(
        main: AppStrings.totalAmountShort(money(amount)),
        detail: AppStrings.peopleInSplit(people),
        balanced: true,
      );
  }
}
