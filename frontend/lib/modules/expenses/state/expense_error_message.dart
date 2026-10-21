import '../../../core/constants/app_strings.dart';
import '../../../data/expenses/expenses_repository.dart';

/// User-facing text for a failed expense create / edit / delete. A 409
/// `GROUP_ARCHIVED` and a 400 `NOT_GROUP_MEMBER` (payer or someone in the
/// split is no longer in the group) get fixed explanations; other API
/// errors use the server's message, and anything else falls back to
/// "[fallback]: error".
String expenseErrorMessage(Object error, {required String fallback}) {
  if (error is ExpensesApiException) {
    if (error.isGroupArchived) return AppStrings.groupArchivedExpenseBlocked;
    if (error.code == 'NOT_GROUP_MEMBER') {
      return AppStrings.notGroupMemberOnExpense;
    }
    return error.message;
  }
  return '$fallback: $error';
}
