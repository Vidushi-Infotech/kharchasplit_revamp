import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/expenses/expense_extras_repository.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';
import 'expense_detail_provider.dart';

/// Edit history of one expense, newest first. Refetched on each open of
/// the sheet (autoDispose) and after a restore.
final expenseHistoryProvider = FutureProvider.autoDispose
    .family<ExpenseHistory, String>((ref, expenseId) {
  return ref.read(expenseExtrasRepositoryProvider).history(expenseId);
});

/// Restores a version and refreshes everything that shows the expense.
class ExpenseHistoryController {
  ExpenseHistoryController(this._ref);
  final Ref _ref;

  /// Returns a user-facing error, or null when the version is back.
  Future<String?> restore({
    required String expenseId,
    required String revisionId,
    String? groupId,
  }) async {
    try {
      await _ref
          .read(expenseExtrasRepositoryProvider)
          .restore(expenseId, revisionId);
    } on ExpensesApiException catch (e) {
      if (e.isGroupArchived) return AppStrings.groupArchivedExpenseBlocked;
      if (e.code == 'MEMBER_LEFT') return AppStrings.restoreMemberLeft;
      if (e.statusCode == 403) return AppStrings.restoreOnlyPayers;
      return e.message;
    } catch (e) {
      return '${AppStrings.restoreFailed}: $e';
    }
    _ref.invalidate(expenseDetailProvider(expenseId));
    _ref.invalidate(expenseHistoryProvider(expenseId));
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(groupsProvider);
    if (groupId != null) _ref.invalidate(groupDetailProvider(groupId));
    return null;
  }
}

final expenseHistoryControllerProvider =
    Provider<ExpenseHistoryController>(ExpenseHistoryController.new);

/// Field-level summary of how [version] differs from [next] (the version
/// that replaced it, or the live expense for the newest revision): one
/// short line per changed field, e.g. "Amount: ₹1,000 → ₹1,200".
List<String> summarizeRevision({
  required ExpenseSnapshot version,
  required ExpenseSnapshot next,
  required String Function(String userId) nameOf,
}) {
  String money(double v) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: CurrencyFormatter.symbolFor(version.currency),
        decimalDigits: v == v.roundToDouble() ? 0 : 2,
      ).format(v);
  String people(Map<String, double> rows) {
    if (rows.length > 2) return AppStrings.peopleCount(rows.length);
    return rows.keys.map(nameOf).join(', ');
  }

  bool sameRows(Map<String, double> a, Map<String, double> b) =>
      a.length == b.length &&
      a.entries.every((e) => ((b[e.key] ?? -1) - e.value).abs() < 0.01);

  final out = <String>[];
  if (version.description.trim() != next.description.trim()) {
    out.add(AppStrings.historyChange(
      AppStrings.description,
      '"${version.description}"',
      '"${next.description}"',
    ));
  }
  if ((version.amount - next.amount).abs() >= 0.01) {
    out.add(AppStrings.historyChange(
      AppStrings.amount,
      money(version.amount),
      money(next.amount),
    ));
  }
  if (!sameRows(version.payers, next.payers)) {
    // Same people but different amounts would read "A, B → A, B": then
    // show the amounts ("A ₹600, B ₹400 → A ₹600, B ₹600").
    String payers(Map<String, double> rows) {
      final samePeople = rows.length == version.payers.length &&
          version.payers.keys.toSet().containsAll(next.payers.keys) &&
          version.payers.length == next.payers.length;
      if (!samePeople || rows.length > 2) return people(rows);
      return (rows.keys.toList()..sort())
          .map((id) => '${nameOf(id)} ${money(rows[id]!)}')
          .join(', ');
    }

    out.add(AppStrings.historyChange(
      AppStrings.paidBy,
      payers(version.payers),
      payers(next.payers),
    ));
  }
  final method = splitMethodLabel(version.splitType, version.isAdjustment);
  final nextMethod = splitMethodLabel(next.splitType, next.isAdjustment);
  if (method != nextMethod) {
    out.add(AppStrings.historyChange(AppStrings.split, method, nextMethod));
  } else if (!sameRows(version.participants, next.participants)) {
    out.add(AppStrings.historySplitChanged(people(version.participants)));
  }
  if (version.category != next.category) {
    out.add(AppStrings.historyCategoryChanged);
  }
  if (version.notes.trim() != next.notes.trim()) {
    out.add(AppStrings.historyNotesChanged);
  }
  if (out.isEmpty) out.add(AppStrings.historyOtherDetails);
  return out;
}

/// "Equally", "By percentage", … for a stored `split_type`.
String splitMethodLabel(String splitType, bool isAdjustment) {
  if (isAdjustment) return AppStrings.splitAdjustment;
  switch (splitType) {
    case 'percentage':
      return AppStrings.splitPercentage;
    case 'shares':
      return AppStrings.splitShares;
    case 'exact':
    case 'unequal':
      return AppStrings.splitExactAmounts;
    default:
      return AppStrings.splitEqually;
  }
}
