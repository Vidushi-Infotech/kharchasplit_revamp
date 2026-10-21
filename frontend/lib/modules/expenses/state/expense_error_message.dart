import '../../../core/constants/app_strings.dart';
import '../../../data/expenses/expenses_repository.dart';

/// User-facing text for a failed expense create / edit / delete. A 409
/// `GROUP_ARCHIVED` gets the fixed explanation; other API errors use the
/// server's message, and anything else falls back to "[fallback]: error".
String expenseErrorMessage(Object error, {required String fallback}) {
  if (error is ExpensesApiException) {
    if (error.isGroupArchived) return AppStrings.groupArchivedExpenseBlocked;
    return error.message;
  }
  return '$fallback: $error';
}
