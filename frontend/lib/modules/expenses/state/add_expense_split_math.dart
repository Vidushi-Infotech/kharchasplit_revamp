import '../../../core/utils/split_calculator.dart';
import '../../../models/models.dart';
import 'add_expense_provider.dart';

/// Pure money maths for the Add/Edit expense form: split modes, what each
/// person owes (in paise), payers and the group's default split. No widgets,
/// no providers — everything here is unit-tested.

/// The five ways the split sheet can split. "By adjustment" has no
/// [SplitType] of its own (the server stores it as exact amounts), so the
/// form tracks it with [AddExpenseState.adjustmentMode].
enum AddExpenseSplitMode { equal, exact, percentage, shares, adjustment }

extension AddExpenseSplitModeX on AddExpenseState {
  AddExpenseSplitMode get splitMode {
    if (adjustmentMode) return AddExpenseSplitMode.adjustment;
    switch (splitType) {
      case SplitType.equal:
        return AddExpenseSplitMode.equal;
      case SplitType.exact:
        return AddExpenseSplitMode.exact;
      case SplitType.percentage:
        return AddExpenseSplitMode.percentage;
      case SplitType.shares:
        return AddExpenseSplitMode.shares;
    }
  }

  /// State after the user picks [mode] in the split sheet. Any explicit pick
  /// ends "using the group's default split".
  AddExpenseState withSplitMode(AddExpenseSplitMode mode) {
    final type = switch (mode) {
      AddExpenseSplitMode.equal => SplitType.equal,
      AddExpenseSplitMode.percentage => SplitType.percentage,
      AddExpenseSplitMode.shares => SplitType.shares,
      AddExpenseSplitMode.exact ||
      AddExpenseSplitMode.adjustment => SplitType.exact,
    };
    return copyWith(
      splitType: type,
      adjustmentMode: mode == AddExpenseSplitMode.adjustment,
      usingGroupDefaultSplit: false,
    );
  }
}

/// State after the user picks [mode] in the split sheet. "By adjustment"
/// needs an explicit list of who's in (empty would read as nobody), so it
/// starts with everyone when nobody was picked yet.
AddExpenseState addExpenseSwitchSplitMode(
  AddExpenseState state,
  AddExpenseSplitMode mode,
  Iterable<String> allMemberIds,
) {
  final next = state.withSplitMode(mode);
  if (mode == AddExpenseSplitMode.adjustment &&
      next.includedMemberIds.isEmpty) {
    return next.copyWith(includedMemberIds: allMemberIds.toSet());
  }
  return next;
}

/// "Split equally" from the default-split hint: equal shares, everyone in.
AddExpenseState addExpenseSplitEquallyForAll(AddExpenseState state) => state
    .withSplitMode(AddExpenseSplitMode.equal)
    .copyWith(includedMemberIds: const {});

/// Who is in the split, sorted by user id. The sort is the "fixed member
/// order" the leftover paise follow, so the form, its validation and the
/// request always agree on who gets them. [allMemberIds] is used when
/// nobody was picked explicitly (= everyone).
List<String> addExpenseIncludedIds(
  AddExpenseState state,
  Iterable<String> allMemberIds,
) {
  final ids = state.includedMemberIds.isNotEmpty
      ? state.includedMemberIds.toList()
      : allMemberIds.toList();
  return ids..sort();
}

/// What each included person owes, in paise, for the current split mode.
/// Equal / percentage / shares / adjustment always sum to the amount exactly;
/// exact amounts are the user's own numbers (validation checks the sum).
Map<String, int> addExpenseOwedPaise(
  AddExpenseState state,
  Iterable<String> allMemberIds,
) {
  final ids = addExpenseIncludedIds(state, allMemberIds);
  final total = SplitCalculator.toPaise(state.amount);
  List<int> owed;
  if (state.adjustmentMode) {
    return adjustmentOwedPaise(state.amount, ids, state.adjustments);
  } else {
    switch (state.splitType) {
      case SplitType.equal:
        owed = SplitCalculator.allocatePaise(total, [for (final _ in ids) 1]);
        break;
      case SplitType.exact:
        owed = [
          for (final id in ids) SplitCalculator.toPaise(state.splits[id] ?? 0),
        ];
        break;
      case SplitType.percentage:
      case SplitType.shares:
        owed = SplitCalculator.allocatePaise(total, [
          for (final id in ids) state.splits[id] ?? 0,
        ]);
        break;
    }
  }
  return {for (var i = 0; i < ids.length; i++) ids[i]: owed[i]};
}

/// "By adjustment" amounts, userId → paise, for the people in [includedIds]
/// (taken in user-id order, see [addExpenseIncludedIds]). Shared by the
/// split sheet's live preview and the request so both show the same paise.
Map<String, int> adjustmentOwedPaise(
  double amount,
  Iterable<String> includedIds,
  Map<String, double> adjustments,
) {
  final ids = includedIds.toList()..sort();
  final owed = SplitCalculator.adjustmentPaise(
    SplitCalculator.toPaise(amount),
    [for (final id in ids) SplitCalculator.toPaise(adjustments[id] ?? 0)],
  );
  return {for (var i = 0; i < ids.length; i++) ids[i]: owed[i]};
}

/// Payers for the request, userId → paise. Multiple payers as entered
/// (zero rows dropped); otherwise [singlePayerId] paid everything. The
/// server needs `payers` on every create / edit (see UPDATE_APP).
Map<String, int> addExpensePayersPaise(
  AddExpenseState state,
  String singlePayerId,
) {
  if (state.payers.isEmpty) {
    return {singlePayerId: SplitCalculator.toPaise(state.amount)};
  }
  return {
    for (final e in state.payers.entries)
      if (SplitCalculator.toPaise(e.value) > 0)
        e.key: SplitCalculator.toPaise(e.value),
  };
}

/// State after saving the "Multiple people" sheet ([amounts]: userId →
/// rupees). Zero rows are dropped; if only one person paid, it is a plain
/// single payer again.
AddExpenseState addExpenseWithPayers(
  AddExpenseState state,
  Map<String, double> amounts,
  List<UserModel> members,
) {
  final paid = {
    for (final e in amounts.entries)
      if (SplitCalculator.toPaise(e.value) > 0)
        e.key: SplitCalculator.roundToPaisa(e.value),
  };
  if (paid.length == 1) {
    final only = members.where((m) => m.id == paid.keys.first).firstOrNull;
    return state.copyWith(payers: const {}, paidBy: only ?? state.paidBy);
  }
  return state.copyWith(payers: paid);
}

/// Paise still to be covered by the payers: amount − Σpayers. Negative when
/// the payers add up to more than the amount.
int payersLeftPaise(double amount, Map<String, double> payers) =>
    SplitCalculator.toPaise(amount) -
    payers.values.fold<int>(0, (s, v) => s + SplitCalculator.toPaise(v));

/// The group's default split (`{type, values}`) turned into a starting split
/// for a new expense, or null when it is unset / unusable. People who left
/// the group are skipped; percentages are renormalised over the rest to sum
/// to exactly 100.00 (leftover hundredths to the first person); members
/// without a value get 0, i.e. they start unticked.
({SplitType type, Map<String, double> values})? groupDefaultSplitFor(
  Map<String, dynamic>? defaultSplit,
  List<UserModel> members,
) {
  if (defaultSplit == null) return null;
  final type = switch (defaultSplit['type']) {
    'percentage' => SplitType.percentage,
    'shares' => SplitType.shares,
    _ => null,
  };
  final raw = defaultSplit['values'];
  if (type == null || raw is! Map) return null;
  final memberIds = members.map((m) => m.id).toSet();
  final kept = <String, double>{
    for (final e in raw.entries)
      if (memberIds.contains(e.key) && e.value is num && (e.value as num) > 0)
        e.key as String: (e.value as num).toDouble(),
  };
  if (kept.isEmpty) return null;
  if (type == SplitType.shares) return (type: type, values: kept);

  final ids = kept.keys.toList()..sort();
  final hundredths = SplitCalculator.allocatePaise(10000, [
    for (final id in ids) kept[id]!,
  ]);
  return (
    type: type,
    values: {for (var i = 0; i < ids.length; i++) ids[i]: hundredths[i] / 100},
  );
}

/// [state] started from the group's default split, or null when the group
/// has none (or nobody in it is still a member) — then the split stays
/// equal. People without a value start unticked.
AddExpenseState? addExpenseStateWithGroupDefault(
  AddExpenseState state,
  Map<String, dynamic>? defaultSplit,
  List<UserModel> members,
) {
  final preset = groupDefaultSplitFor(defaultSplit, members);
  if (preset == null) return null;
  return state.copyWith(
    splitType: preset.type,
    adjustmentMode: false,
    splits: {for (final m in members) m.id: preset.values[m.id] ?? 0},
    includedMemberIds: preset.values.keys.toSet(),
    usingGroupDefaultSplit: true,
  );
}
