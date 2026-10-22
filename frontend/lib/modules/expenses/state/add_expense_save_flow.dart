import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../../../modules/groups/state/group_detail_provider.dart';
import '../../../modules/groups/state/groups_provider.dart';
import '../screens/add_expense_screen.dart';
import '../widgets/repeat_edit_scope_sheet.dart';
import 'add_expense_form_helpers.dart';
import 'add_expense_fx.dart';
import 'add_expense_provider.dart';
import 'add_expense_submit.dart';
import 'expense_error_message.dart';

/// Save / close orchestration for [AddExpenseScreen]'s State.
///
/// A mixin on the screen's own `ConsumerState`, so `context`, `ref`,
/// `widget` and `mounted` are exactly the screen's — the async gaps keep
/// the same `mounted` guards. Payload building, the API call and cache
/// invalidation live in add_expense_submit.dart.
mixin AddExpenseSaveFlow on ConsumerState<AddExpenseScreen> {
  void _saveBlocked(String message) {
    HapticService.instance.error();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Archived group: nothing can be saved until an admin unarchives it.
  void blockArchivedSave() =>
      _saveBlocked(AppStrings.groupArchivedExpenseBlocked);

  /// Save tapped while it can't save: archived group → its explanation;
  /// otherwise what's missing ([addExpenseMissingFieldHint]), after
  /// [revealErrors] red-highlights the fields that block it.
  void explainBlockedSave({
    required bool archived,
    required AddExpenseState state,
    required VoidCallback revealErrors,
  }) {
    if (state.isLoading) return;
    if (archived) return blockArchivedSave();
    revealErrors();
    final hint = addExpenseMissingFieldHint(state);
    if (hint == null) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _saveBlocked(hint);
  }

  Future<void> handleSave() async {
    final state = ref.read(addExpenseProvider);
    if (state.title == null || state.title!.trim().isEmpty) {
      return _saveBlocked('Add a title before saving.');
    }
    if (state.groupId == null) {
      return _saveBlocked('Pick a group before saving the expense.');
    }
    final groupId = state.groupId!;
    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) {
      return _saveBlocked('You must be signed in to save an expense.');
    }

    // The detail the form already watches; non-group (direct) groups are
    // never in groupsProvider, so that list is only a fallback.
    final group =
        ref.read(groupDetailProvider(groupId)).value?.group ??
        (ref.read(groupsProvider).value ?? const <GroupModel>[])
            .firstWhereOrNull((g) => g.id == groupId);
    if (group?.isArchived ?? false) return blockArchivedSave();
    final members = group?.members ?? const <UserModel>[];
    final paidBy = resolveExpensePayer(state, members, currentUser);
    final participants = buildExpenseParticipants(state, members, paidBy);

    // Editing a recurring expense: just this one, or this and future ones?
    final ruleId = widget.isEditing ? state.recurringRuleId : null;
    var scope = RepeatEditScope.justThisOne;
    if (ruleId != null &&
        (ref.read(featureFlagsProvider).value?.contains('recurring') ??
            false)) {
      final picked = await askRepeatEditScope(
        context,
        isDark: Theme.of(context).brightness == Brightness.dark,
      );
      if (picked == null || !mounted) return; // Cancel: nothing saved.
      scope = picked;
    }

    ref.read(addExpenseProvider.notifier).state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      await submitExpense(
        ref.read(expensesRepositoryProvider),
        expenseId: widget.isEditing ? widget.expenseId! : null,
        groupId: groupId,
        state: state,
        paidBy: paidBy,
        participants: participants,
        groupCurrency: group?.currency,
      );
    } catch (e) {
      if (!mounted) return;
      HapticService.instance.error();
      // 409 GROUP_ARCHIVED (archived meanwhile) → the clear explanation.
      final message = expenseErrorMessage(
        e,
        fallback: 'Could not save expense',
      );
      ref.read(addExpenseProvider.notifier).state = state.copyWith(
        isLoading: false,
        error: message,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // The expense is saved; a failed rule update only warns (403: not the
    // person who set up the repeat, nor an admin).
    String? futureWarning;
    if (scope == RepeatEditScope.thisAndFuture) {
      futureWarning = await updateRecurringFuture(
        ref.read(recurringRepositoryProvider),
        ruleId: ruleId!,
        template: () => recurringTemplateAfterSave(
          ref.read(expensesRepositoryProvider),
          expenseId: widget.expenseId!,
          state: state,
          paidBy: paidBy,
          participants: participants,
          groupCurrency: group?.currency,
        ),
      );
    }

    invalidateAfterExpenseSave(
      ref,
      groupId: groupId,
      expenseId: widget.isEditing ? widget.expenseId! : null,
    );

    if (!mounted) return;
    HapticService.instance.success();
    ref.read(addExpenseProvider.notifier).state = AddExpenseState(
      date: DateTime.now(),
    );
    final saved = scope == RepeatEditScope.thisAndFuture
        ? '✓ ${AppStrings.repeatFutureUpdated}'
        : widget.isEditing
        ? '✓ Expense updated'
        : '✓ Expense saved';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(futureWarning ?? saved),
        backgroundColor: futureWarning == null
            ? AppColors.success
            : AppColors.warning,
        duration: Duration(seconds: futureWarning == null ? 2 : 5),
      ),
    );
    closeScreen();
  }

  void closeScreen() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go('/home/groups');
    }
  }
}
