import 'package:collection/collection.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/models.dart';
import '../../groups/state/group_display.dart';
import 'add_expense_provider.dart';
import 'add_expense_split_math.dart';

/// Pure text for the "Paid by [you] and split [equally]." line of the
/// Add/Edit expense form, and the group switch that goes with the
/// "With you and:" chip. No widgets, no providers.

/// The payer pill: "you", "Asha K." or "3 people" (several payers).
String addExpensePaidByPill(
  AddExpenseState state,
  List<UserModel> members,
  String? myId,
) {
  if (state.payers.length > 1) {
    return AppStrings.peopleCount(state.payers.length);
  }
  final payerId = state.payers.keys.firstOrNull ?? state.paidBy?.id ?? myId;
  if (payerId == null || payerId == myId) return AppStrings.youLower;
  final name = state.paidBy?.id == payerId
      ? state.paidBy!.name
      : members.firstWhereOrNull((m) => m.id == payerId)?.name ?? '';
  return name.trim().isEmpty ? AppStrings.youLower : NameFormat.short(name);
}

/// The split pill: "equally", "unequally", "by percentages", "by shares",
/// "by adjustment" — or "by group default" while the split is still the
/// group's default one.
String addExpenseSplitPill(AddExpenseState state) {
  if (state.usingGroupDefaultSplit) return AppStrings.splitPillGroupDefault;
  switch (state.splitMode) {
    case AddExpenseSplitMode.equal:
      return AppStrings.splitPillEqually;
    case AddExpenseSplitMode.exact:
      return AppStrings.splitPillExact;
    case AddExpenseSplitMode.percentage:
      return AppStrings.splitPillPercent;
    case AddExpenseSplitMode.shares:
      return AppStrings.splitPillShares;
    case AddExpenseSplitMode.adjustment:
      return AppStrings.splitPillAdjustment;
  }
}

/// The whole sentence, e.g. "Paid by you and split equally." (screen
/// readers and tests; the form draws the two pills itself).
String addExpensePaidSplitSentence(
  AddExpenseState state,
  List<UserModel> members,
  String? myId,
) => AppStrings.paidSplitSentence(
  addExpensePaidByPill(state, members, myId),
  addExpenseSplitPill(state),
);

/// State after picking another group (or friend) for a new expense: what
/// was typed (description, amount, category, date, notes, receipt, repeat)
/// stays; everything tied to the old group's members (payers, split,
/// currency choice) starts over, equally between everyone.
AddExpenseState addExpenseStateForGroup(AddExpenseState s, String groupId) {
  return AddExpenseState(
    title: s.title,
    amount: s.amount,
    category: s.category,
    categoryTouched: s.categoryTouched,
    date: s.date,
    notes: s.notes,
    groupId: groupId,
    invoiceImagePath: s.invoiceImagePath,
    invoiceScanned: s.invoiceScanned,
    receiptBase64: s.receiptBase64,
    repeat: s.repeat,
  );
}

/// Name on the "With you and:" chip and the bottom bar: the group's name,
/// or the friend's for the hidden two-person group. Null until loaded.
String? addExpenseGroupLabel(GroupModel? group, String? myId) {
  if (group == null) return null;
  if (!group.isDirect) return group.name;
  final friend = group.directFriend(myId)?.name ?? '';
  return friend.trim().isEmpty ? AppStrings.nonGroupExpenses : friend;
}
