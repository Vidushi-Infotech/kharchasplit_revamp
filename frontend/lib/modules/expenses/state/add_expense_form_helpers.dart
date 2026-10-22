import 'package:flutter/painting.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_catalog.dart';
import '../../../models/models.dart';
import 'add_expense_fx.dart';
import 'add_expense_provider.dart';
import 'add_expense_validation.dart';

/// Pure helpers backing the Add/Edit expense form. No widget state, no
/// providers — just mapping and formatting of [AddExpenseState].

/// Maps a fetched [ExpenseModel] onto the form state used in edit mode.
/// [inOriginalCurrency] (`currencyConversion` on): an expense entered in
/// another currency reopens in it, with its original amounts.
AddExpenseState addExpenseStateFromExpense(
  ExpenseModel expense, {
  bool inOriginalCurrency = false,
}) {
  final splits = <String, double>{};
  final included = <String>{};
  for (final s in expense.splits) {
    double value;
    switch (expense.splitType) {
      case SplitType.percentage:
        value = s.percentage;
        break;
      case SplitType.shares:
        value = s.shares;
        break;
      case SplitType.exact:
      case SplitType.equal:
        value = s.owedShare;
        break;
    }
    splits[s.userId] = value;
    if (value > 0) included.add(s.userId);
  }

  // "By adjustment" reopens as adjustments, with everyone who was in it
  // (someone can owe ₹0 after a negative adjustment).
  final rawAdjustments = expense.splitMeta?['adjustments'];
  final adjustments = <String, double>{
    if (expense.isAdjustmentSplit && rawAdjustments is Map)
      for (final e in rawAdjustments.entries)
        if (e.value is num) e.key as String: (e.value as num).toDouble(),
  };
  if (expense.isAdjustmentSplit) {
    included.addAll(expense.splits.map((s) => s.userId));
  }

  // Never drop payers: a multi-payer expense always reopens with them,
  // whatever the multiPayer flag says.
  final payers = expense.hasMultiplePayers
      ? {for (final p in expense.payers) p.userId: p.amount}
      : const <String, double>{};
  final original = inOriginalCurrency && expense.isConverted
      ? addExpenseAmountsInOriginal(expense, splits, payers)
      : null;

  return AddExpenseState(
    title: expense.title,
    amount: original?.amount ?? expense.amount,
    currency: original != null
        ? CurrencyCatalog.symbolFor(expense.originalCurrency!)
        : expense.currency,
    entryCurrency: original != null ? expense.originalCurrency : null,
    savedFx: original != null ? addExpenseSavedFxOf(expense) : null,
    category: expense.category,
    paidBy: expense.paidBy,
    splitType: expense.splitType,
    splits: original?.splits ?? splits,
    includedMemberIds: included,
    date: expense.date,
    notes: expense.notes,
    groupId: expense.groupId,
    receiptBase64: expense.receiptBase64,
    payers: original?.payers ?? payers,
    adjustmentMode: expense.isAdjustmentSplit,
    adjustments: original != null
        ? adjustments
        : addExpenseAdjustmentsInGroup(expense, adjustments),
    // Editing never auto-changes the category.
    categoryTouched: true,
    recurringRuleId: expense.recurringRuleId,
    baseUpdatedAt: expense.updatedAtRaw,
  );
}

String formatAddExpenseDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = DateTime(d.year, d.month, d.day);
  final diff = today.difference(picked).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return '$diff days ago';
  return '${picked.day}/${picked.month}/${picked.year}';
}

Color? addExpenseHexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var s = hex.replaceFirst('#', '');
  if (s.length == 6) s = 'FF$s';
  final value = int.tryParse(s, radix: 16);
  return value == null ? null : Color(value);
}

/// Returns a short, actionable hint describing what's missing to enable
/// Save. `null` when the form is ready to submit. Used as the disabled
/// button label so users immediately see *why* they can't save yet.
String? addExpenseMissingFieldHint(AddExpenseState state) {
  if (state.isValid) return null;
  final hasTitle = (state.title ?? '').trim().isNotEmpty;
  final hasAmount = state.amount > 0;
  if (!hasTitle && !hasAmount) return 'Enter amount and title';
  if (!hasAmount) return 'Enter amount';
  if (!hasTitle) return 'Enter title';
  if (state.groupId == null) return 'Pick a group';
  if (!state.isSplitValid) return 'Fix the split';
  if (state.repeatError != null) return 'Fix the repeat end date';
  if (!state.isPayersValid) return 'Fix who paid';
  return 'Complete required fields';
}

/// Who's in the split, in words: "Everyone", "Everyone except Ravi" or
/// "Only Asha, Ravi" (whichever list is shorter). An empty [included] set
/// means everyone unless [emptyMeansNobody] (the "By adjustment" list).
String addExpenseWhoIsIn(
  List<UserModel> members,
  Set<String> included, {
  bool emptyMeansNobody = false,
}) {
  if (included.isEmpty) {
    return emptyMeansNobody ? AppStrings.nobodyInSplit : AppStrings.everyone;
  }
  final inSplit = members.where((m) => included.contains(m.id)).toList();
  final out = members.where((m) => !included.contains(m.id)).toList();
  if (inSplit.isEmpty) return AppStrings.nobodyInSplit;
  if (out.isEmpty) return AppStrings.everyone;
  String names(List<UserModel> people) {
    final shown = people.take(3).map((m) => m.name).join(', ');
    return people.length > 3 ? '$shown +${people.length - 3}' : shown;
  }

  return out.length <= inSplit.length
      ? AppStrings.everyoneExcept(names(out))
      : AppStrings.onlyNames(names(inSplit));
}
