import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/keep_alive_for.dart';
import '../../../data/expenses/expense_extras_repository.dart';
import '../../../data/expenses/expenses_repository.dart';

/// Comments on one expense, oldest first. Invalidated after a post / delete
/// and when an EXPENSE_COMMENT push for this expense arrives in the
/// foreground (push_refresh_provider.dart).
final expenseCommentsProvider = FutureProvider.autoDispose
    .family<List<ExpenseComment>, String>((ref, expenseId) async {
  keepAliveFor(ref, const Duration(minutes: 2));
  return ref.read(expenseExtrasRepositoryProvider).listComments(expenseId);
});

/// Post / delete comments. Returns a user-facing error message, or null on
/// success, so the UI only has to show it.
class ExpenseCommentsController {
  ExpenseCommentsController(this._ref);
  final Ref _ref;

  static const maxLength = 1000;

  ExpenseExtrasRepository get _repo =>
      _ref.read(expenseExtrasRepositoryProvider);

  Future<String?> add(String expenseId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      await _repo.addComment(expenseId, text);
      _ref.invalidate(expenseCommentsProvider(expenseId));
      return null;
    } catch (e) {
      return _message(e, 'Could not post the comment');
    }
  }

  Future<String?> delete(String expenseId, String commentId) async {
    try {
      await _repo.deleteComment(expenseId, commentId);
      _ref.invalidate(expenseCommentsProvider(expenseId));
      return null;
    } catch (e) {
      return _message(e, 'Could not delete the comment');
    }
  }

  /// 429 (too fast) and 400 (length) carry readable server messages.
  static String _message(Object e, String fallback) =>
      e is ExpensesApiException ? e.message : '$fallback. Check your connection.';
}

final expenseCommentsControllerProvider =
    Provider<ExpenseCommentsController>(ExpenseCommentsController.new);
