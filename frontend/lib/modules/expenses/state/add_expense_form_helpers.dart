import 'package:flutter/painting.dart';

import '../../../models/models.dart';
import 'add_expense_provider.dart';

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
  );
}

String addExpenseSplitSummary(AddExpenseState state, List<UserModel> members) {
  final count = state.includedMemberIds.isEmpty
      ? members.length
      : state.includedMemberIds.length;
  if (count == 0) return 'Equally';
  switch (state.splitType) {
    case SplitType.equal:
      return 'Equally · $count ${count == 1 ? 'person' : 'people'}';
    case SplitType.exact:
      return 'By amounts · $count';
    case SplitType.percentage:
      return 'By percent · $count';
    case SplitType.shares:
      return 'By shares · $count';
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
  return 'Complete required fields';
}
