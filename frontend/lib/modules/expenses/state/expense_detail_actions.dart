import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/expenses/expenses_repository.dart';
import '../../../data/groups/groups_repository.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import 'expense_detail_provider.dart';

/// Delete / remind from the expense detail screen. Errors are thrown to
/// the screen, which turns them into a SnackBar.
class ExpenseDetailActions {
  ExpenseDetailActions(this._ref);
  final Ref _ref;

  /// Deletes the expense and refreshes the balances that included it.
  Future<void> delete(String expenseId) async {
    // Capture the group BEFORE the expense is gone — its detail provider
    // needs refreshing after the delete succeeds.
    final groupId = _ref.read(expenseDetailProvider(expenseId)).value?.groupId;
    await _ref
        .read(expensesRepositoryProvider)
        .delete(expenseId, groupId: groupId);
    _ref.invalidate(dashboardProvider);
    if (groupId != null) _ref.invalidate(groupDetailProvider(groupId));
  }

  Future<void> remind({required String groupId, required String userId}) =>
      _ref
          .read(groupsRepositoryProvider)
          .sendReminder(groupId: groupId, userId: userId);
}

final expenseDetailActionsProvider = Provider<ExpenseDetailActions>(
  ExpenseDetailActions.new,
);
