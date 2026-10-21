import 'package:flutter/painting.dart';

import '../../../core/constants/app_strings.dart';
import '../../../models/models.dart';
import 'add_expense_provider.dart';
import 'add_expense_validation.dart';

/// Pure helpers backing the Add/Edit expense form. No widget state, no
/// providers — just mapping and formatting of [AddExpenseState].

/// Maps a fetched [ExpenseModel] onto the form state used in edit mode.
AddExpenseState addExpenseStateFromExpense(ExpenseModel expense) {
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

  return AddExpenseState(
    title: expense.title,
    amount: expense.amount,
    currency: expense.currency,
    category: expense.category,
    paidBy: expense.paidBy,
    splitType: expense.splitType,
    splits: splits,
    includedMemberIds: included,
    date: expense.date,
    notes: expense.notes,
    groupId: expense.groupId,
    receiptBase64: expense.receiptBase64,
    // Never drop payers: a multi-payer expense always reopens with them,
    // whatever the multiPayer flag says.
    payers: expense.hasMultiplePayers
        ? {for (final p in expense.payers) p.userId: p.amount}
        : const {},
    adjustmentMode: expense.isAdjustmentSplit,
    adjustments: adjustments,
    // Editing never auto-changes the category.
    categoryTouched: true,
  );
}

/// Value of the "Paid by" row: "You", a name, "You and Asha" or "3 people".
String addExpensePaidBySummary(
  AddExpenseState state,
  List<UserModel> members,
  String? myId,
) {
  String nameOf(String id) =>
      members.where((m) => m.id == id).map((m) => m.name).firstOrNull ?? '';
  if (state.payers.length == 2 &&
      myId != null &&
      state.payers.containsKey(myId)) {
    final other = state.payers.keys.firstWhere((id) => id != myId);
    return AppStrings.youAndName(nameOf(other));
  }
  if (state.payers.length > 1) {
    return AppStrings.peopleCount(state.payers.length);
  }
  final payerId = state.payers.keys.firstOrNull ?? state.paidBy?.id ?? myId;
  if (payerId == null || payerId == myId) return 'You';
  return state.paidBy?.id == payerId ? state.paidBy!.name : nameOf(payerId);
}

String addExpenseSplitSummary(AddExpenseState state, List<UserModel> members) {
  final count = state.includedMemberIds.isEmpty
      ? members.length
      : state.includedMemberIds.length;
  if (count == 0) return 'Equally';
  if (state.adjustmentMode) return '${AppStrings.splitAdjustment} · $count';
  switch (state.splitType) {
    case SplitType.equal:
      return 'Equally · $count ${count == 1 ? 'person' : 'people'}';
    case SplitType.exact:
      return 'By amounts · $count';
    case SplitType.percentage:
    case SplitType.shares:
      final how = state.splitType == SplitType.percentage
          ? 'By percent'
          : 'By shares';
      // Started from the group's default split: say so on the row too.
      return state.usingGroupDefaultSplit
          ? '${AppStrings.groupDefaultShort} · $how'
          : '$how · $count';
  }
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
