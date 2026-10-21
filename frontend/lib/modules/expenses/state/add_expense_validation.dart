import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/split_calculator.dart';
import '../../../models/models.dart';
import 'add_expense_provider.dart';
import 'add_expense_split_math.dart';

/// Whether the Add/Edit expense form can be saved, and why not. Money checks
/// are exact to the paisa — the server rejects anything else
/// (SPLIT_MISMATCH / PAYERS_MISMATCH).
extension AddExpenseValidation on AddExpenseState {
  bool get isValid {
    // Title is required so the expense list / detail / activity feed all
    // show a meaningful label. We require ≥1 non-whitespace character.
    if (title == null || title!.trim().isEmpty) return false;
    if (amount <= 0) return false;
    return isSplitValid && isPayersValid;
  }

  /// Whether the split breakdown itself is valid for the current split type,
  /// independent of title/amount. Equal split (and the no-group case) is
  /// always valid. Used to disable the split sheet's Done button and to flag
  /// the Split row on the form.
  bool get isSplitValid => groupId == null || _splitProblem == null;

  /// Short reason the split is invalid, or null when valid. Surfaced on the
  /// Split row so the user sees *why* it's blocking the save.
  String? get splitError => groupId == null ? null : _splitProblem;

  String? get _splitProblem {
    if (adjustmentMode) {
      if (includedMemberIds.isEmpty) return AppStrings.nobodyInSplit;
      // Every included id is known here, so no member list is needed.
      final owed = addExpenseOwedPaise(this, const []);
      return owed.values.any((p) => p < 0)
          ? AppStrings.adjustmentsTooLarge
          : null;
    }
    if (splitType == SplitType.equal) return null;
    if (splits.isEmpty) return 'Set each share';

    final includedSum = splits.entries
        .where(
          (e) => includedMemberIds.isEmpty || includedMemberIds.contains(e.key),
        )
        .fold<double>(0, (sum, e) => sum + e.value);

    switch (splitType) {
      case SplitType.exact:
        // Exact to the paisa, not "within 0.01".
        final assigned = splits.entries
            .where(
              (e) =>
                  includedMemberIds.isEmpty ||
                  includedMemberIds.contains(e.key),
            )
            .fold<int>(0, (s, e) => s + SplitCalculator.toPaise(e.value));
        final diff = SplitCalculator.toPaise(amount) - assigned;
        if (diff == 0) return null;
        return diff > 0
            ? '${CurrencyFormatter.format(diff / 100)} left to assign'
            : AppStrings.amountOver(CurrencyFormatter.format(-diff / 100));
      case SplitType.percentage:
        final diff = 100 - includedSum;
        if (diff.abs() < 0.01) return null;
        return diff > 0
            ? '${diff.toStringAsFixed(1)}% left to assign'
            : 'Over by ${(-diff).toStringAsFixed(1)}%';
      case SplitType.shares:
        return includedSum > 0 ? null : 'Set at least one share';
      case SplitType.equal:
        return null;
    }
  }

  /// Single payer always adds up; multiple payers must each have paid
  /// something and together exactly the amount.
  bool get isPayersValid =>
      payers.isEmpty ||
      (payers.values.every((v) => SplitCalculator.toPaise(v) >= 0) &&
          payers.values.any((v) => SplitCalculator.toPaise(v) > 0) &&
          payersLeftPaise(amount, payers) == 0);

  /// Why the payers don't add up (e.g. the amount changed after they were
  /// entered — never rescaled silently), or null.
  String? get payersError {
    if (isPayersValid) return null;
    final left = payersLeftPaise(amount, payers);
    if (left > 0) {
      return AppStrings.amountOfTotalLeft(
        CurrencyFormatter.format(left / 100),
        CurrencyFormatter.format(amount),
      );
    }
    return left < 0
        ? AppStrings.amountOver(CurrencyFormatter.format(-left / 100))
        : AppStrings.payersDontAddUp;
  }
}
