import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/split_calculator.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../../../models/models.dart';
import '../../../modules/dashboard/state/dashboard_provider.dart';
import '../../../modules/groups/state/group_detail_provider.dart';
import '../../../modules/groups/state/groups_provider.dart';
import 'add_expense_fx.dart';
import 'add_expense_provider.dart';
import 'add_expense_split_math.dart';
import 'expense_detail_provider.dart';
import 'expense_error_message.dart';
import 'recurring_rule_provider.dart';

/// Non-UI pieces of the Add/Edit expense save flow: payer resolution,
/// split math / request payload, the create-or-update API call, and the
/// post-save cache invalidation. The screen keeps the orchestration that
/// touches BuildContext (snackbars, haptics, navigation, `mounted`).

/// Payer for the request: explicit pick, else me as a group member, else a
/// [UserModel] built from the signed-in user.
UserModel resolveExpensePayer(
  AddExpenseState state,
  List<UserModel> members,
  UserModel currentUser,
) {
  return state.paidBy ??
      members.firstWhereOrNull((m) => m.id == currentUser.id) ??
      UserModel(
        id: currentUser.id,
        name: currentUser.name,
        email: currentUser.email,
        phone: currentUser.phone,
        avatarUrl: currentUser.avatarUrl,
        createdAt: currentUser.createdAt,
      );
}

/// Per-participant amounts (and percentage / shares) for the request.
/// Amounts come from [addExpenseOwedPaise], so for every split mode they add
/// up to the amount exactly — the server rejects a split off by one paisa.
List<ExpenseParticipant> buildExpenseParticipants(
  AddExpenseState state,
  List<UserModel> members,
  UserModel paidBy,
) {
  final memberById = {for (final m in members) m.id: m};
  final owed = addExpenseOwedPaise(state, members.map((m) => m.id));
  if (owed.isEmpty) {
    return [
      ExpenseParticipant(
        userId: paidBy.id,
        name: paidBy.name,
        amount: state.amount,
      ),
    ];
  }
  final isPercentage =
      !state.adjustmentMode && state.splitType == SplitType.percentage;
  final isShares = !state.adjustmentMode && state.splitType == SplitType.shares;
  return [
    for (final e in owed.entries)
      ExpenseParticipant(
        userId: e.key,
        name: memberById[e.key]?.name ?? e.key,
        amount: e.value / 100,
        percentage: isPercentage ? (state.splits[e.key] ?? 0) : null,
        shares: isShares ? (state.splits[e.key] ?? 0).round() : null,
      ),
  ];
}

/// `splitType` for the request. "By adjustment" goes as 'adjustment' (with
/// [backendSplitMeta]); the server stores it as exact amounts.
String backendSplitTypeFor(AddExpenseState state) =>
    state.adjustmentMode ? 'adjustment' : backendSplitType(state.splitType);

/// `splitMeta` for the request: the adjustments of an "By adjustment" split
/// (only for people in the split), else null.
Map<String, dynamic>? backendSplitMeta(
  AddExpenseState state,
  List<ExpenseParticipant> participants,
) {
  if (!state.adjustmentMode) return null;
  return {
    'adjustments': {
      for (final p in participants)
        p.userId: SplitCalculator.roundToPaisa(
          state.adjustments[p.userId] ?? 0,
        ),
    },
  };
}

String backendSplitType(SplitType t) {
  switch (t) {
    case SplitType.equal:
      return 'equal';
    case SplitType.percentage:
      return 'percentage';
    case SplitType.shares:
      return 'shares';
    case SplitType.exact:
      return 'unequal';
  }
}

/// PUTs to /expenses/:id when [expenseId] is non-null, else POSTs a new one
/// (with the form's `repeat`, if any — the new expense is then the first
/// occurrence of a recurring rule). Entered in another currency: amounts go
/// in it with `originalCurrency` (+ `fxRate` when the user gave one) and
/// the server converts them into [groupCurrency].
Future<void> submitExpense(
  ExpensesRepository repo, {
  required String? expenseId,
  required String groupId,
  required AddExpenseState state,
  required UserModel paidBy,
  required List<ExpenseParticipant> participants,
  String? groupCurrency,
}) async {
  // Always send payers (built from the single payer when there's one): an
  // edit of a multi-payer expense without them is refused (UPDATE_APP).
  final payersPaise = addExpensePayersPaise(state, paidBy.id);
  final splitType = backendSplitTypeFor(state);
  final splitMeta = backendSplitMeta(state, participants);
  // Saved in the group's currency: converted from another one, or typed
  // in it. The form's symbol is only a fallback when the group is unknown.
  final currency = state.entryCurrency != null || groupCurrency != null
      ? groupCurrencyCode(groupCurrency)
      : state.currency;
  final fxRate = addExpenseFxRateOverride(state);
  if (expenseId != null) {
    await repo.update(
      expenseId,
      description: state.title!.trim(),
      amount: state.amount,
      currency: currency,
      category: (state.category ?? CategoryModel.other).id,
      notes: state.notes,
      expenseDate: state.date,
      receiptBase64: state.receiptBase64,
      paidById: paidBy.id,
      splitType: splitType,
      participants: participants,
      payersPaise: payersPaise,
      splitMeta: splitMeta,
      baseUpdatedAt: state.baseUpdatedAt,
      groupId: groupId,
      originalCurrency: state.entryCurrency,
      fxRate: fxRate,
    );
  } else {
    await repo.create(
      groupId: groupId,
      description: state.title!.trim(),
      amount: state.amount,
      currency: currency,
      category: (state.category ?? CategoryModel.other).id,
      paidById: paidBy.id,
      paidByName: paidBy.name,
      splitType: splitType,
      notes: state.notes,
      expenseDate: state.date,
      receiptBase64: state.receiptBase64,
      participants: participants,
      payersPaise: payersPaise,
      splitMeta: splitMeta,
      repeat: state.repeat.toJson(),
      originalCurrency: state.entryCurrency,
      fxRate: fxRate,
    );
  }
}

/// Template for PUT /recurring/:id ("this and future"): exactly the expense
/// edit's payload — same payers and split, so it passes the same
/// exact-to-the-paisa checks (SPLIT_MISMATCH / PAYERS_MISMATCH).
Map<String, dynamic> buildRecurringTemplate({
  required AddExpenseState state,
  required UserModel paidBy,
  required List<ExpenseParticipant> participants,
}) {
  final notes = state.notes?.trim() ?? '';
  return {
    'description': (state.title ?? '').trim(),
    'amount': state.amount,
    'currency': normalizeCurrencyCode(state.currency),
    'category': (state.category ?? CategoryModel.other).id,
    'notes': notes.isEmpty ? null : notes,
    'splitType': backendSplitTypeFor(state),
    'splitMeta': backendSplitMeta(state, participants),
    'payers': expensePayersJson(addExpensePayersPaise(state, paidBy.id)),
    'participants': [for (final p in participants) p.toJson()],
  };
}

/// "This and future": the rule creates [template] from now on (expenses
/// already created stay as they are). Returns null on success, else what
/// to tell the user — the expense edit itself is already saved by then.
Future<String?> updateRecurringFuture(
  RecurringRepository repo, {
  required String ruleId,
  required Future<Map<String, dynamic>> Function() template,
}) async {
  try {
    await repo.update(ruleId, template: await template());
    return null;
  } catch (e) {
    return recurringFutureErrorMessage(e);
  }
}

/// Refreshes every cache that shows the saved expense.
void invalidateAfterExpenseSave(
  WidgetRef ref, {
  required String groupId,
  required String? expenseId,
}) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(groupDetailProvider(groupId));
  // Re-fetch the groups list so the dashboard "Your Groups" carousel picks
  // up the new recency order (this group jumps to the front now that the
  // backend bumped its updated_at).
  ref.invalidate(groupsProvider);
  if (expenseId != null) {
    ref.invalidate(expenseDetailProvider(expenseId));
  }
  // A new repeat or a "this and future" edit changes the rules shown on
  // the expense detail and the group's Recurring expenses list.
  ref.invalidate(recurringRuleProvider);
  ref.invalidate(groupRecurringRulesProvider(groupId));
}

/// Equal-split write-back. The derivation lives in
/// [equalSplitDerivedProvider] — a pure function of (amount,
/// splitType, includedMemberIds, members). `ref.listen` fires only
/// when the EqualSplitDerived value structurally changes (the class
/// implements ==).
///
/// The state write is deferred to a post-frame callback because the
/// derived provider watches addExpenseProvider — writing back
/// synchronously inside the listener dirties the dependency, and
/// Riverpod refuses to recompute the same provider twice in one
/// frame ("Bad state: Tried to rebuild `Provider<EqualSplitDerived?>`
/// multiple times in the same frame"). Posting the write to the
/// next frame lets Riverpod's per-frame bookkeeping reset; the
/// structural `==` on EqualSplitDerived then short-circuits the
/// next listener fire (prev == next) and the loop terminates.
///
/// Must be called from the screen's `build` (it registers a `ref.listen`).
void listenEqualSplitWriteBack(
  WidgetRef ref,
  String? groupId, {
  required bool Function() isMounted,
}) {
  ref.listen<EqualSplitDerived?>(equalSplitDerivedProvider(groupId), (
    prev,
    next,
  ) {
    if (next == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      final current = ref.read(addExpenseProvider);
      // Stale fire: the split moved off "equally" (e.g. the group's default
      // split was applied) after this write was scheduled.
      if (current.splitType != SplitType.equal || current.adjustmentMode) {
        return;
      }
      if (mapEquals(current.splits, next.splits) &&
          setEquals(current.includedMemberIds, next.includedMemberIds)) {
        return;
      }
      ref.read(addExpenseProvider.notifier).state = current.copyWith(
        splits: next.splits,
        includedMemberIds: next.includedMemberIds,
      );
    });
  });
}
