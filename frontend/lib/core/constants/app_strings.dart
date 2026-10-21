/// User-facing wording for money concepts — the single source of truth.
///
/// Terms follow the conventions people already know from Splitwise
/// ("you owe", "you are owed", "Settle up", "Record payment", "By exact
/// amounts"…), so the same idea is never called three different things on
/// three screens. New UI must use these; existing screens move over in the
/// naming pass (Phase 1). This file is also the source for the future
/// gen-l10n ARB files (Hindi).
///
/// Rules of thumb:
/// * Sentence case for buttons and titles ("Settle up", not "Settle Up").
/// * "payment" for money one person gives another (a settlement row);
///   "expense" for a bill being split.
/// * Amounts are passed in already formatted (CurrencyFormatter / intl).
abstract final class AppStrings {
  // ── Balances ────────────────────────────────────────────────────────
  static const youOwe = 'You owe';
  static const youAreOwed = 'You are owed';
  static const owesYou = 'owes you';
  static const settledUp = 'Settled up';
  static const allSettledUp = 'All settled up';
  static String overallYouOwe(String amount) => 'Overall, you owe $amount';
  static String overallYouAreOwed(String amount) =>
      'Overall, you are owed $amount';
  static String youOweName(String name, String amount) =>
      'You owe $name $amount';
  static String nameOwesYou(String name, String amount) =>
      '$name owes you $amount';
  static String settledUpWith(String name) =>
      'You are all settled up with $name';
  static const youAreAllSettledUp = 'You are all settled up';
  // Lower-case variants for the trailing balance on list rows.
  static const youOweLower = 'you owe';
  static const settledUpLower = 'settled up';
  static String inGroupNameOwesYou(String group, String name, String amount) =>
      'In $group: $name owes you $amount';
  static String inGroupYouOwe(String group, String amount) =>
      'In $group: you owe $amount';
  static const hideSettledUpFriends = 'Hide settled-up friends';
  static const chooseGroupToSettle = 'Which group do you want to settle?';
  static const chooseGroupToRemind = 'Which group do you want to remind about?';
  static String reminderSent(String name) => 'Reminder sent to $name';

  // ── Expenses ────────────────────────────────────────────────────────
  static const addExpense = 'Add expense';
  static const editExpense = 'Edit expense';
  static const saveExpense = 'Save';
  static const description = 'Description';
  static const descriptionHint = 'Enter a description';
  static const amount = 'Amount';
  static const paidBy = 'Paid by';
  static const split = 'Split';
  static const date = 'Date';
  static const category = 'Category';
  static const notes = 'Notes';
  static const receipt = 'Receipt';
  static const nonGroupExpenses = 'Non-group expenses';
  static String paidByAndSplit(String payer, String how) =>
      'Paid by $payer and split $how';

  // ── Split methods ───────────────────────────────────────────────────
  static const splitEqually = 'Equally';
  static const splitExactAmounts = 'By exact amounts';
  static const splitPercentage = 'By percentage';
  static const splitShares = 'By shares';
  static const splitAdjustment = 'By adjustment';
  static String amountLeft(String amount) => '$amount left';

  // ── Payments (settlements) ──────────────────────────────────────────
  static const settleUp = 'Settle up';
  static const settleAllBalances = 'Settle all balances';
  static const recordPayment = 'Record payment';
  static const recordCashPayment = 'Record a cash payment';
  static const payments = 'Payments';
  static const remind = 'Remind';
  static String paidName(String from, String to, String amount) =>
      '$from paid $to $amount';
  static const paymentMethod = 'Paid with';
  static const paymentRecorded = 'Payment recorded';

  // ── Groups & people ─────────────────────────────────────────────────
  static const groups = 'Groups';
  static const friends = 'Friends';
  static const activity = 'Activity';
  static const account = 'Account';
  static const createGroup = 'Create a group';
  static const addPeople = 'Add people';
  static const invited = 'Invited';
  static const balances = 'Balances';
  static const totals = 'Totals';
  static const expenses = 'Expenses';

  // ── Group lifecycle (archive / complete) ────────────────────────────
  static const archiveGroup = 'Archive group';
  static const unarchiveGroup = 'Unarchive group';
  static const unarchive = 'Unarchive';
  static const markComplete = 'Mark as complete';
  static const groupArchived = 'This group is archived';
  static const groupCompleted = 'Completed — all settled up';
  static const unarchiveToAddExpenses = 'Unarchive to add expenses';
  static const settleUpFirst = 'Settle up first';
  static const groupArchivedExpenseBlocked =
      'This group is archived. Unarchive it to add or change expenses.';
  static String archiveWithOpenBalance(String amount) =>
      '$amount is still unsettled in this group. Archiving hides the group '
      'and stops new expenses, but balances stay open and payments can '
      'still be recorded.';
  static String completeNeedsSettle(String amount) =>
      '$amount is still unsettled in this group. Everyone needs to be '
      'settled up before it can be marked complete.';

  // ── Navigation (tab bar, Account, Groups list) ─────────────────────
  static const personalExpenses = 'Personal expenses';
  static const reports = 'Reports';
  static const notifications = 'Notifications';
  static const goToGroups = 'Go to groups';
  static const archived = 'Archived';
  static const completed = 'Completed';
  static String archivedGroupsCount(int n) => 'Archived groups ($n)';
  static const noActiveGroups = 'No active groups';
  static const noActiveGroupsHint =
      'Your archived groups are below. Start a new group any time.';
  static const whatsNewTitle = 'A new look';
  static const whatsNewGroups =
      'Groups is your new home — your overall balance is at the top';
  static const whatsNewFriends =
      'Friends shows what each person owes you across groups';
  static const whatsNewAccount =
      'Personal expenses and Reports are under Account';
  static const gotIt = 'Got it';
}
