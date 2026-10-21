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
  // Non-group ("direct") expenses with one friend (nonGroup is below).
  static String youAndName(String name) => 'You and $name';
  static String withName(String name) => 'With $name';
  static String inGroupName(String group) => 'In $group';
  static const notGroupMemberOnExpense =
      'Everyone on an expense must be a member of the group';

  // ── Split methods ───────────────────────────────────────────────────
  static const splitEqually = 'Equally';
  static const splitExactAmounts = 'By exact amounts';
  static const splitPercentage = 'By percentage';
  static const splitShares = 'By shares';
  static const splitAdjustment = 'By adjustment';
  static String amountLeft(String amount) => '$amount left';
  // Add/edit expense form: multiple payers, by adjustment, who's in.
  static const multiplePeople = 'Multiple people';
  static const whoPaid = 'Who paid?';
  static const howMuchEachPaid = 'How much did each person pay?';
  static String peopleCount(int n) => '$n people';
  static String amountOfTotalLeft(String left, String total) =>
      '$left of $total left';
  static String amountOver(String amount) => 'Over by $amount';
  static String paidAmountFor(String name) => 'Amount $name paid';
  static const payersDontAddUp = "What people paid doesn't add up";
  static const payersMismatch =
      'What each person paid must add up to the total exactly.';
  static const splitMismatch =
      'The split must add up to the total exactly. Check the amounts.';
  static const updateAppToEditExpense =
      'This expense was paid by more than one person. Update KharchaSplit '
      'to edit it.';
  static const splitAdjustmentShort = 'Equal ± extra';
  static const adjustmentHint =
      'Everyone pays an equal part, then add or take off an amount for '
      'anyone — e.g. +150 for an extra drink.';
  static const adjustmentsTooLarge = 'Adjustments are more than the total';
  static String adjustmentFor(String name) => 'Adjustment for $name';
  static const flipAdjustmentSign = 'Switch between adding and taking off';
  static String owesAmount(String amount) => 'Owes $amount';
  static const usingGroupDefaultSplit = "Using the group's default split";
  static const groupDefaultShort = 'Group default';
  static const splitEquallyInstead = 'Split equally';
  static const everyone = 'Everyone';
  static String everyoneExcept(String names) => 'Everyone except $names';
  static String onlyNames(String names) => 'Only $names';
  static const nobodyInSplit = 'Nobody is in the split yet';
  static const notInThisSplit = 'Not in this split';
  static const selectAllPeople = 'All';
  static const selectNoPeople = 'None';

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

  // ── Friends & non-group expenses ────────────────────────────────────
  static const nonGroup = 'Non-group';
  static String nonGroupYouOwe(String amount) =>
      'Non-group expenses: you owe $amount';
  static String nonGroupNameOwesYou(String name, String amount) =>
      'Non-group expenses: $name owes you $amount';
  static const addFriend = 'Add friend';
  static const addFriendHint =
      'Find them by phone number to split expenses without a group.';
  static const pickFromContacts = 'Pick from contacts';
  static const findFriend = 'Find';
  static const enterTenDigitNumber = 'Enter a 10-digit mobile number';
  static const thatIsYourNumber = "That's your own number";
  static const notOnKharchaSplitYet = 'Not on KharchaSplit yet';
  static const notOnKharchaSplitHint =
      'Invite them. Once they sign up, you can add expenses together.';
  static const invite = 'Invite';
  static const inviteFriendMessage =
      "Hey! I'm using KharchaSplit to split expenses. Join me so we can keep "
      'track of who owes what.';
  static const tooManySearches =
      'Too many searches. Try again in a few minutes.';
  static const lookupFailed =
      'Lookup failed. Check your connection and try again.';
  static const pickOnePerson =
      'Pick one person. Splitting with more than one? Create a group.';
  static const splitWithMoreCreateGroup =
      'Splitting with more than one person? Create a group.';
  static const pickGroupOrFriend = 'Pick a group or a friend';
  static const searchGroupsOrFriends = 'Search groups or friends';
  static String couldNotOpenNonGroup(String error) =>
      'Could not start a non-group expense: $error';

  // ── Expense detail: payers, comments, edit history ──────────────────
  static String namePaidAmount(String name, String amount) =>
      '$name paid $amount';
  static String peoplePaid(int n) => '$n people paid';
  static const comments = 'Comments';
  static const addComment = 'Add a comment';
  static const sendComment = 'Send comment';
  static const noCommentsYet = 'No comments yet';
  static const noCommentsYetHint =
      'Ask a question or add details everyone on this expense can see.';
  static const commentsLoadFailed = 'Could not load comments';
  static const retry = 'Retry';
  static const formerMember = 'Former member';
  static const deleteCommentTitle = 'Delete comment?';
  static const deleteCommentBody = "This can't be undone.";
  static const delete = 'Delete';
  static const cancel = 'Cancel';
  static const commentDeleted = 'Comment deleted';
  static const longPressToDelete = 'Long-press to delete';
  static const editHistory = 'Edit history';
  static const editHistoryHint = 'See and restore earlier versions';
  static const noEditsYet = 'No edits yet';
  static const noEditsYetHint = 'Earlier versions show here after an edit.';
  static const editHistoryLoadFailed = 'Could not load the edit history';
  static String editedByName(String name, String when) =>
      'Edited by $name · $when';
  static String historyChange(String field, String from, String to) =>
      '$field: $from → $to';
  static String historySplitChanged(String people) =>
      'Split: different amounts ($people)';
  static const historyCategoryChanged = 'Category changed';
  static const historyNotesChanged = 'Notes changed';
  static const historyOtherDetails = 'Other details changed';
  static const restoreThisVersion = 'Restore this version';
  static const restoreVersionTitle = 'Restore this version?';
  static const restoreVersionBody =
      'The expense goes back to how it was in this version. Balances '
      'recalculate for everyone, and the current version stays in the '
      'history.';
  static const restore = 'Restore';
  static const versionRestored = 'Earlier version restored';
  static const restoreFailed = 'Could not restore this version';
  static const restoreMemberLeft =
      "Someone in that version has left the group, so it can't be restored.";
  static const restoreOnlyPayers =
      'Only someone who paid for this expense can restore a version.';

  // ── Group default split ─────────────────────────────────────────────
  static const defaultSplit = 'Default split';
  static const defaultSplitHint =
      'New expenses in this group start with this split. It can still be '
      'changed on each expense.';
  static const percentage = 'Percentage';
  static const shares = 'Shares';
  static String percentTotal(String total) => 'Total: $total% of 100%';
  static String sharesTotal(String total) => 'Total: $total shares';
  static const percentagesMustTotal100 = 'Percentages must add up to 100';
  static const sharesMustBePositive = 'Give at least one person a share';
  static const clearDefaultSplit = 'Clear (split equally)';
  static const save = 'Save';
  static const defaultSplitSaved = 'Default split saved';
  static const defaultSplitCleared =
      'Default split cleared — expenses split equally';
  static const equallyByDefault = 'Equally (no default)';

  // ── Recurring expenses: add / edit expense form ─────────────────────
  static const repeatRowLabel = 'Repeat';
  static const repeatNever = 'Never';
  static String repeatUntil(String date) => 'until $date';
  static const repeatEndsLabel = 'Ends';
  static const repeatNeverEnds = 'Never ends';
  static String repeatEndsOn(String date) => 'On $date';
  static const repeatPickEndDate = 'Pick the last date';
  static const repeatEndBeforeDate =
      'The end date must be on or after the expense date';
  static const repeatFirstIsThis =
      'This expense is the first one. The next ones are added '
      'automatically and everyone is told.';
  static const repeatPastDatesNote =
      'Past dates will be added automatically (up to 3).';
  static const repeatDone = 'Done';
  static const repeatEditScopeTitle =
      'Change just this expense, or this and future ones?';
  static const repeatEditScopeHint =
      'Expenses already added are not changed.';
  static const repeatJustThisOne = 'Just this one';
  static const repeatThisAndFuture = 'This and future';
  static const repeatFutureUpdated = 'Expense and future repeats updated';
  static const repeatFutureForbidden =
      'Saved this expense. Only the person who set up the repeat can '
      'change future ones.';
  static String repeatFutureFailed(String reason) =>
      'Saved this expense, but future ones were not changed: $reason';

  // ── Recurring expenses: manage (detail card, group list) ────────────
  static const recurringExpenses = 'Recurring expenses';
  static const recurringBadge = 'Recurring';
  static String recurringRepeats(String everyX) => 'Repeats $everyX';
  static String recurringNextOn(String date) => 'Next on $date';
  static String recurringEndsOn(String date) => 'Ends $date';
  static const recurringPaused = 'Paused';
  static String recurringPausedBecause(String reason) => 'Paused — $reason';
  static const recurringEnded = 'Ended';
  static const recurringStopped = 'Stopped';
  static const recurringStoppedHint =
      'This no longer repeats. Expenses already added stay.';
  static const recurringLoadFailed = 'Could not load the repeat details';
  static const recurringManage = 'Manage';
  static const recurringPause = 'Pause';
  static const recurringResume = 'Resume';
  static const recurringChange = 'Change frequency or end date';
  static const recurringStop = 'Stop repeating';
  static const recurringStopTitle = 'Stop repeating?';
  static const recurringStopBody =
      "Future expenses won't be added. Expenses already added stay.";
  static const recurringPausedDone = 'Paused. No new expenses will be added.';
  static const recurringResumedDone = 'Resumed';
  static const recurringStoppedDone = 'Stopped repeating';
  static const recurringUpdatedDone = 'Repeat updated';
  static const recurringActionFailed =
      'Could not update. Check your connection and try again.';
  static const recurringHowOften = 'How often';
  static const recurringEndDate = 'End date';
  static const recurringNoEndDate = 'No end date';
  static const recurringPickEndDate = 'Pick end date';
  static const recurringClearEndDate = 'Remove end date';
  static const recurringNone = 'No recurring expenses';
  static const recurringNoneHint = 'Choose Repeat when adding an expense.';
  static const recurringListLoadFailed = 'Could not load recurring expenses';
  static String recurringPaidBy(String names) => 'Paid by $names';
  static const recurringOnlyCreatorOrAdmin =
      'Only the person who set it up or a group admin can change it.';
}
