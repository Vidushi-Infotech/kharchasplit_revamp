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
  static String settleAllBalancesIn(String currency) =>
      'Settle all balances ($currency)';
  static const settleUpOneGroup = 'Settle up one group';
  static String settleAllGroupYouOwe(String group, String amount) =>
      '$group — you owe $amount';
  static String settleAllGroupOwesYou(
    String group,
    String name,
    String amount,
  ) =>
      '$group — $name owes you $amount';
  static String totalYouPay(String name, String amount) =>
      'Total you pay $name: $amount';
  static String settleAllExplain(int groups) =>
      'Balances in all $groups groups are settled with one payment.';
  static String recordAmountPayment(String amount) =>
      'Record $amount payment';
  static const balancesChangedCheckTotal =
      'Balances changed — check the new total';
  static String settledUpWithName(String name) => 'Settled up with $name';
  static String nothingToPayName(String name) =>
      "You don't owe $name anything overall right now.";
  static const nothingToSettle = 'Nothing to settle';
  static const notesOptional = 'Notes (optional)';

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
  static const simplifyGroupDebts = 'Simplify group debts';
  static const simplifyGroupDebtsHint =
      'Combines debts to reduce the number of payments. Nobody owes more or '
      'less in total.';
  static const simplifyDebtsTurnedOn = 'Simplify group debts turned on';
  static const simplifyDebtsTurnedOff = 'Simplify group debts turned off';
  static const simplified = 'Simplified';
  static const simplifiedBalancesHint =
      'Simplify group debts is on: debts are combined to reduce the number '
      'of payments, so who you pay can differ from the expense log. Nobody '
      'owes more or less in total.';
  static const on = 'On';
  static const off = 'Off';

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

  // ── UPI (pay by UPI, UPI ID on the profile) ─────────────────────────
  static const upiId = 'UPI ID';
  static const upiIdHint = 'name@okhdfcbank';
  static const upiIdHelper =
      'So friends can pay you with one tap. Only people who owe you can see it.';
  static const upiIdInvalid = 'Enter a valid UPI ID, like name@okhdfcbank';
  static const addUpiId = 'Add';
  static String upiNote(String group) => 'KharchaSplit - $group';
  static String payWithUpi(String amount) => 'Pay $amount with UPI';
  static const upiLimitWarning = 'UPI allows up to ₹1,00,000 per payment';
  static String askForUpiId(String name) => 'Ask $name for their UPI ID';
  static String upiIdRequested(String name) =>
      'Asked $name to add their UPI ID';
  static String didUpiPaymentGoThrough(String amount, String name) =>
      'Did your $amount payment to $name go through?';
  static const upiCheckYourApp =
      'Check your UPI app. Only record it once the money has left your account.';
  static String yesRecordAmount(String amount) => 'Yes, record $amount';
  static const upiNotPaid = 'No';
  static const iHavePaidRecordIt = 'I’ve paid — record it';
  static String payNameByUpi(String name) => 'Pay $name by UPI';
  static const noUpiAppFound =
      'No UPI app opened. Copy the UPI ID or scan the QR with your phone.';
  static const scanWithUpiApp = 'Scan with any UPI app';
  static const copyUpiId = 'Copy UPI ID';
  static const upiIdCopied = 'UPI ID copied';
  static const iHavePaid = 'I’ve paid';
  static const upiRequestFailed =
      'Could not send the request. Check your connection.';

  // ── Payment checks ("Not received") ─────────────────────────────────
  static const notReceived = 'Not received';
  static const markNotReceivedTitle = 'Payment not received?';
  static String markNotReceivedBody(String amount, String name) =>
      'Mark $amount from $name as not received? The payment will be '
      'removed and the amount will show as owed again. $name will be '
      'notified.';
  static const markNotReceived = 'Mark not received';
  static const keepPayment = 'Cancel';
  static String markedNotReceived(String name) =>
      'Payment removed. $name has been notified.';
  static const notReceivedFailed =
      'Could not update the payment. Check your connection.';

  // ── Settle all + UPI ────────────────────────────────────────────────
  static String upiRecordedInGroup(String group) =>
      'Balances had changed, so your UPI payment was recorded in $group';
  static String upiPaidNotRecorded(String error) =>
      'Your UPI payment went through but could not be recorded ($error). '
      'Record it from the group with "Record payment".';
}
