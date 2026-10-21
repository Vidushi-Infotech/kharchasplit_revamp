import '../../../core/constants/app_strings.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../data/recurring/recurring_repository.dart';

/// User-facing text for a failed expense create / edit / delete. A 409
/// `GROUP_ARCHIVED` and a 400 `NOT_GROUP_MEMBER` (payer or someone in the
/// split is no longer in the group) get fixed explanations; other API
/// errors use the server's message, and anything else falls back to
/// "[fallback]: error". Payer / split totals that are off by a paisa
/// (PAYERS_MISMATCH / SPLIT_MISMATCH) and UPDATE_APP get their own text.
String expenseErrorMessage(Object error, {required String fallback}) {
  if (error is ExpensesApiException) {
    if (error.isGroupArchived) return AppStrings.groupArchivedExpenseBlocked;
    if (error.code == 'NOT_GROUP_MEMBER') {
      return AppStrings.notGroupMemberOnExpense;
    }
    if (error.isPayersMismatch) return AppStrings.payersMismatch;
    if (error.isSplitMismatch) return AppStrings.splitMismatch;
    if (error.needsAppUpdate) return AppStrings.updateAppToEditExpense;
    return error.message;
  }
  return '$fallback: $error';
}

/// Text shown when the expense edit saved but updating its recurring rule
/// ("this and future") failed. 403 = not the rule's creator or a group
/// admin; the split / payer / member codes get the same wording as on an
/// expense.
String recurringFutureErrorMessage(Object error) {
  if (error is RecurringApiException) {
    if (error.statusCode == 403) return AppStrings.repeatFutureForbidden;
    final reason = switch (error.code) {
      'NOT_GROUP_MEMBER' => AppStrings.notGroupMemberOnExpense,
      'PAYERS_MISMATCH' => AppStrings.payersMismatch,
      'SPLIT_MISMATCH' => AppStrings.splitMismatch,
      _ => error.message,
    };
    return AppStrings.repeatFutureFailed(reason);
  }
  return AppStrings.repeatFutureFailed('$error');
}
