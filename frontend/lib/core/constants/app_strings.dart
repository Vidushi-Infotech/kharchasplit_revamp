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
  static const youAreOwedLower = 'you are owed';
  // Trailing label on an expense row (from the viewer's side).
  static const youLent = 'you lent';
  static const youBorrowed = 'you borrowed';
  static const notInvolved = 'not involved';
  static const noExpenses = 'no expenses';
  static String youPaidAmount(String amount) => 'You paid $amount';
  static String plusMoreBalances(int n) =>
      'Plus $n more balance${n == 1 ? '' : 's'}';
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
      'anyone, e.g. +150 for an extra drink.';
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
      '$group: you owe $amount';
  static String settleAllGroupOwesYou(
    String group,
    String name,
    String amount,
  ) =>
      '$group: $name owes you $amount';
  static String totalYouPay(String name, String amount) =>
      'Total you pay $name: $amount';
  static String settleAllExplain(int groups) =>
      'Balances in all $groups groups are settled with one payment.';
  static String recordAmountPayment(String amount) =>
      'Record $amount payment';
  static const balancesChangedCheckTotal =
      'Balances changed. Check the new total';
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
  static const invitedMember = 'Invited member';
  static const balances = 'Balances';
  static const totals = 'Totals';
  static const expenses = 'Expenses';

  // ── Group lifecycle (archive / complete) ────────────────────────────
  static const archiveGroup = 'Archive group';
  static const unarchiveGroup = 'Unarchive group';
  static const unarchive = 'Unarchive';
  static const markComplete = 'Mark as complete';
  static const groupArchived = 'This group is archived';
  static const groupCompleted = 'Completed, all settled up';
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
  // The two "apps": the last tab switches between them.
  static const personal = 'Personal';
  static const switchToPersonal = 'Switch to Personal';
  static const switchToGroups = 'Switch to Groups';

  // ── Personal mode: money in and out ─────────────────────────────────
  static const personalHome = 'Home';
  static const personalExpense = 'Expense';
  static const personalIncome = 'Income';
  static const addPersonalExpense = 'Add personal expense';
  static const addIncome = 'Add income';
  static const saveIncome = 'Save income';
  static const incomeAdded = 'Income added';
  static const personalExpenseAdded = 'Personal expense added';
  static const payFrom = 'Pay from';
  static const receivedIn = 'Received in';
  static const pickPaySource = 'Pick a source to pay from.';
  static const pickReceiveSource = 'Pick where the money went.';
  static const incomeHint = 'e.g. Salary, Freelance, Refund';
  static const thisMonth = 'This month';
  static const moneyIn = 'In';
  static const moneyOut = 'Out';
  static const net = 'Net';
  static const transactions = 'Transactions';

  // ── Personal mode: Insights ─────────────────────────────────────────
  static const insights = 'Insights';
  static const insightsSpent = 'Spent';
  static const insightsSaved = 'Saved';
  static const insightsOverspent = 'Overspent';
  static const insightsSavingsRate = 'Kept';
  static const insightsMoreThan = 'more than';
  static const insightsLessThan = 'less than';
  static String insightsSameAs(String month) => 'Same as $month';
  static String insightsNothingToCompare(String month) =>
      'Nothing spent in $month to compare';
  static const insightsByCategory = 'By category';
  static const insightsTotal = 'Total';
  static const insightsNew = 'New';
  static const insightsSame = 'Same';
  static const insightsDaily = 'Day by day';
  static const insightsAverage = 'Avg';
  static const insightsPerDay = '/day';
  static const insightsSixMonths = 'Last 6 months';
  static const insightsIncomeFrom = 'Income by source';
  static const insightsEmptyTitle = 'Nothing this month yet';
  static const insightsEmptyBody =
      'Add expenses or income and see where your money goes.';
  static const insightsLoadError = "Couldn't load insights";

  // ── Personal mode: Budgets ──────────────────────────────────────────
  static const budgets = 'Budgets';
  static const budgetMonth = 'Monthly budget';
  static const budgetCategories = 'Category budgets';
  static const budgetNotBudgeted = 'Spent without a budget';
  static const budgetOf = 'of';
  static const budgetLeft = 'left';
  static const budgetOver = 'over';
  static const budgetSetMonth = 'Set a monthly budget';
  static const budgetSetMonthBody =
      'One limit for everything you spend in a month.';
  static const budgetAdd = 'Add budget';
  static const budgetEdit = 'Edit budget';
  static const budgetSet = 'Set budget';
  static const budgetRemove = 'Remove budget';
  static const budgetAmount = 'Monthly limit';
  static const budgetWholeMonth = 'Whole month';
  static const budgetPickCategory = 'For';
  static const budgetSaved = 'Budget saved';
  static const budgetRemoved = 'Budget removed';
  static const budgetSaveFailed = "Couldn't save the budget. Try again.";
  static const budgetLoadError = "Couldn't load budgets";
  static const budgetEmptyTitle = 'No budgets yet';
  static const budgetEmptyBody =
      'Set a limit for the month or for a category. You get an alert at 80% '
      'and when you go over.';
  static String budgetSafePerDay(String amount, int days) =>
      '$amount a day for the next ${days == 1 ? 'day' : '$days days'}';
  static const budgetNearTitle = 'Budget almost used';
  static const budgetOverTitle = 'Over budget';
  static String budgetSpentThisMonth(String amount) =>
      '$amount spent this month';

  // ── Personal mode: Accounts ─────────────────────────────────────────
  static const accounts = 'Accounts';
  static const accountCash = 'Cash';
  static const accountBank = 'Bank';
  static const accountCard = 'Card';
  static const accountWallet = 'Wallet';
  static const accountDue = 'due';
  static const accountsNetWorth = 'Net balance';
  static const accountsEmptyTitle = 'No accounts yet';
  static const accountsEmptyBody =
      'Add cash, a bank account, a card or a wallet to see where your money is.';
  static const accountAdd = 'Add account';
  static const accountManage = 'Manage accounts';
  static const accountTransfer = 'Transfer';
  static const accountTransferTitle = 'Move money';
  static const accountTransferFrom = 'From';
  static const accountTransferTo = 'To';
  static const accountTransferNote = 'Note (optional, e.g. ATM)';
  static const accountTransferDone = 'Transfer saved';
  static const accountTransferFailed = "Couldn't save the transfer. Try again.";
  static const accountTransferNeedTwo = 'Add a second account to move money.';
  static const accountTransfers = 'Transfers';
  static const accountEntries = 'Recent entries';
  static const accountNoActivity = 'Nothing on this account yet.';
  static const accountLoadError = "Couldn't load accounts";
  static const accountDeleteTransfer = 'Delete transfer?';
  static String accountEntryCount(int n) => n == 1 ? '1 entry' : '$n entries';
  static const profile = 'Profile';

  // ── Personal mode: Bills ────────────────────────────────────────────
  static const bills = 'Bills';
  static const billsUpcoming = 'Upcoming bills';
  static const billsSeeAll = 'See all';
  static const billsOverdue = 'Overdue';
  static const billsDueSoon = 'Due soon';
  static const billsLater = 'Later';
  static const billAdd = 'Add bill';
  static const billEdit = 'Edit bill';
  static const billName = 'Name';
  static const billNameHint = 'e.g. Electricity, Rent, Netflix';
  static const billAmount = 'Amount';
  static const billRepeats = 'Repeats';
  static const billNextDue = 'Next due date';
  static const billRemind = 'Remind me';
  static const billPayFrom = 'Pay from';
  static const billSave = 'Save bill';
  static const billRemove = 'Remove bill';
  static const billPay = 'Pay';
  static const billMarkPaid = 'Mark as paid';
  static const billSkip = 'Skip this one';
  static const billPaid = 'Paid. It moves to the next due date.';
  static const billSkipped = 'Skipped to the next due date';
  static const billSaved = 'Bill saved';
  static const billRemoved = 'Bill removed';
  static const billFailed = "Couldn't save. Try again.";
  static const billLoadError = "Couldn't load bills";
  static const billsEmptyTitle = 'No bills yet';
  static const billsEmptyBody =
      'Add rent, electricity, subscriptions or EMIs. You get a reminder before '
      'each one is due, and paying it adds the expense for you.';
  static const billWeekly = 'Weekly';
  static const billBiweekly = 'Every 2 weeks';
  static const billMonthly = 'Monthly';
  static const billYearly = 'Yearly';
  static const billDueToday = 'Due today';
  static const billDueTomorrow = 'Due tomorrow';
  static String billDueIn(int days) => 'Due in $days days';
  static String billDueOn(String date) => 'Due $date';
  static String billOverdueBy(int days) =>
      'Overdue by ${days == 1 ? '1 day' : '$days days'}';
  // ── Personal mode: voice entry ──────────────────────────────────────
  static const voiceAdd = 'Add by voice';
  static const voiceTitle = 'Say it';
  static const voiceStarting = 'Getting the mic ready…';
  static const voiceListening = 'Listening…';
  static const voiceExamples =
      'Try "200 rupees petrol", "kal 450 ka khana cash se" or '
      '"got salary 50000"';
  static const voiceUnavailable =
      "Voice isn't available. Allow the microphone for KharchaSplit in "
      'Settings, or type it instead.';
  static const voiceNothingHeard = "Didn't catch that.";
  static const voiceNoAmount = "No amount heard. Say it with a number.";
  static const voiceAgain = 'Say again';
  static const voiceUse = 'Use this';
  static const voiceStart = 'Start listening';
  static const voiceStop = 'Stop listening';
  static const voiceYesterday = 'Yesterday';
  static String voiceDaysAgo(int days) => '$days days ago';
  static const voiceFilled = 'Filled in from your voice. Check and save.';

  static String billRemindDays(int days) => switch (days) {
    0 => 'On the day',
    1 => '1 day before',
    _ => '$days days before',
  };
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
      'Groups is your new home. Your overall balance is at the top';
  static const whatsNewFriends =
      'Friends shows what each person owes you across groups';
  static const whatsNewAccount =
      'Personal expenses and Reports are under Account';
  static const whatsNewAddExpense =
      'Tap Add expense at the bottom right to add a bill';
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
  static const iHavePaidRecordIt = 'I’ve paid, record it';
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
      'Default split cleared. Expenses split equally';
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
  static String recurringPausedBecause(String reason) => 'Paused: $reason';
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

  // ── Offline mode ────────────────────────────────────────────────────
  static const offlineNoConnection = 'No internet connection';
  static String offlineShowingDataFrom(String ago) =>
      'Offline · showing data from $ago';
  static const savedOffline =
      'Saved offline. It will sync when you\'re back online';
  static const unsyncedChanges = 'Unsynced changes';
  static String unsyncedChangesCount(int n) => 'Unsynced changes ($n)';
  static const pendingSync = 'Pending sync';
  static const notSynced = 'Not synced';
  static const syncAllNow = 'Sync now';
  static const retrySync = 'Retry';
  static const discardChange = 'Discard';
  static const discardChangeTitle = 'Discard this change?';
  static const discardChangeBody =
      'It was never sent, so nobody else will see it.';
  static const noUnsyncedChanges = 'Everything is synced';
  static const waitingForConnection = 'Waiting for connection';
  static const syncing = 'Syncing…';
  static String logoutUnsyncedWarning(int n) => n == 1
      ? '1 change hasn\'t synced yet and will be lost if you log out.'
      : '$n changes haven\'t synced yet and will be lost if you log out.';
  static const syncConflict =
      'Someone changed this expense while you were offline. Open it and edit again.';
  static const syncExpenseDeleted = 'This expense was deleted, so the change was dropped.';
  static const syncNotMember = 'You\'re no longer in this group.';
  static const syncGroupArchived = 'This group is archived.';
  static const openExpense = 'Open expense';
  static const editConflictOnline =
      'Someone else changed this expense just now. Close it, reopen and edit again.';
  static const upiNeedsInternet = 'UPI needs an internet connection';

  // ── Group totals tab ────────────────────────────────────────────────
  static const totalsTab = 'Totals';
  static const periodThisMonth = 'This month';
  static const periodLastMonth = 'Last month';
  static const periodThisYear = 'This year';
  static const periodAllTime = 'All time';
  static const totalGroupSpending = 'Total group spending';
  static const totalYouPaidFor = 'Total you paid for';
  static const yourTotalShare = 'Your total share';
  static const paymentsMadeReceived = 'Payments made / received';
  static const totalsByCategory = 'By category';
  static const totalsByMonth = 'By month';
  static const totalsPaidVsShare = 'Paid vs share';
  static const totalsPaid = 'Paid';
  static const totalsShare = 'Share';
  static const totalsYou = 'you';
  static const totalsNoExpenses = 'No expenses in this period';
  static const totalsNoExpensesHint = 'Pick another period or add an expense.';
  static String totalsExpenseCount(int n) =>
      n == 1 ? '1 expense' : '$n expenses';
  static String totalsPendingExcluded(int n) => n == 1
      ? '1 unsynced expense isn\'t included yet'
      : '$n unsynced expenses aren\'t included yet';

  // ── Search ──────────────────────────────────────────────────────────
  static const search = 'Search';
  static const searchHint = 'Search expenses, groups, friends';
  static const searchStartHint = 'Find any expense, group or friend.';
  static const searchTypeMore = 'Type at least 2 characters';
  static const searchRecent = 'Recent searches';
  static const searchClearRecent = 'Clear';
  static String searchRemoveRecent(String q) => 'Remove "$q" from recent';
  static const searchFailed = 'Could not search';
  static const searchNeedsInternet = 'Search needs an internet connection';
  static String searchNoResults(String q) => 'No results for "$q"';
  static const searchNoResultsHint = 'Try a shorter or different word.';
  static const searchClear = 'Clear search';

  // ── Export (CSV, PDF statement) ─────────────────────────────────────
  static const exportToExcel = 'Export to Excel';
  static const exportToCsv = 'Export to CSV';
  static const exportStatementPdf = 'Download group statement (PDF)';
  static const exportMyExpensesCsv = 'Export my expenses (CSV)';
  static const exportStatementPeriod = 'Statement period';
  static const exportStatementPeriodHint =
      'Balances are always as of today; the expense list follows the period.';
  static const exportCreate = 'Create PDF';
  static const exportPreparing = 'Preparing your file…';
  static const exportFailed = 'Could not export';
  static String exportShareSubject(String name) => 'KharchaSplit: $name';
  static const statementTitle = 'Group statement';
  static String statementGenerated(String date) => 'Generated on $date';
  static String statementPeriod(String period) => 'Period: $period';
  static const statementTotals = 'Totals';
  static const statementBalances = 'Balances (as of today)';
  static const statementWhoOwes = 'Who owes whom';
  static const statementSimplified = 'Simplified debts are on for this group.';
  static const statementAllSettled = 'Everyone is settled up.';
  static const statementMember = 'Member';
  static const statementNet = 'Net';
  static const statementDate = 'Date';
  static const statementDescription = 'Description';
  static const statementAmount = 'Amount';
  static const statementNoExpenses = 'No expenses in this period.';
  static const statementPendingNote =
      'Expenses still waiting to sync from this phone are not included.';
  static String statementOwes(String from, String to) => '$from owes $to';

  // ── Receipt scan & other currencies (add / edit expense form) ───────
  static const receiptScanning = 'Reading the receipt…';
  static String receiptUseTotal(String amount) =>
      'Use $amount from the receipt?';
  static const receiptFound = 'Found on the receipt';
  static const receiptNoTotal = "Couldn't read the total";
  static const receiptUnreadable = "Couldn't read this receipt";
  static const receiptFieldAmount = 'Amount';
  static const receiptFieldDate = 'Date';
  static const receiptFieldTitle = 'Title';
  static String receiptReplaces(String current) => 'Replaces $current';
  static const receiptUse = 'Use';
  static const receiptNotNow = 'Not now';
  static const invalidReceipt =
      "This receipt can't be uploaded. Use a photo or PDF under 8 MB.";
  static const currencyTitle = 'Currency';
  static const currencyGroupDefault = 'Group currency';
  static const currencyRecent = 'Recent';
  static String currencyTapToChange(String code) =>
      'Currency $code. Tap to change';
  static String fxApprox(String converted, String rateLine, String date) =>
      '≈ $converted at $rateLine ($date)';
  static const fxYourRate = 'your rate';
  static const fxLoading = 'Getting the exchange rate…';
  static const fxUnavailable = 'Exchange rate unavailable';
  static const fxEnterRate = 'Enter rate';
  static const fxChangeRate = 'Change';
  static String fxRateQuestion(String from, String to) =>
      'How much is 1 $from in $to?';
  static const fxRateHint =
      'Use the rate on your bank or card statement. Everyone in the group '
      'sees this rate.';
  static const fxUseRate = 'Use this rate';
  static const fxUnavailableOnSave =
      "Couldn't get the exchange rate. Tap Enter rate under the amount, "
      'then save again.';
  static String fxPaidOriginal(String amount, String rateLine, String date) =>
      'Paid $amount · $rateLine on $date';

  // ── Tabs redesign (U2) ──
  // Groups tab
  static const createGroupTooltip = 'Create group';
  static const filterGroups = 'Filter groups';
  static const groupsFilterAll = 'All groups';
  static const groupsFilterOutstanding = 'Outstanding balances';
  static const groupsFilterYouOwe = 'Groups you owe';
  static const groupsFilterOweYou = 'Groups that owe you';
  static const startNewGroup = 'Start a new group';
  static String showArchivedGroups(int n) =>
      'Show $n archived ${n == 1 ? 'group' : 'groups'}';
  static const hideArchivedGroups = 'Hide archived groups';
  static const groupsFilteredNote = 'Showing only some of your groups';

  // Friends tab
  static String inGroupYouOweName(String group, String name, String amount) =>
      'In $group: you owe $name $amount';
  static String plusMoreGroups(int n) =>
      'Plus $n more ${n == 1 ? 'group' : 'groups'}';
  static const addMoreFriends = 'Add more friends';

  // Activity tab — sentence pieces ("You added "Dinner" in "Trip".")
  static const activityYou = 'You';
  static const activityYouLower = 'you';
  static const activitySomeone = 'Someone';
  static const activityAnExpense = 'an expense';
  static const activityAdded = 'added';
  static const activityUpdated = 'updated';
  static const activityDeleted = 'deleted';
  static const activityIn = 'in';
  static const activityFrom = 'from';
  static const activityTo = 'to';
  static const activityPaid = 'paid';
  static const activityConfirmedPaymentFrom = 'confirmed a payment from';
  static const activityDeletedPaymentFrom = 'deleted a payment from';
  static const activityCreatedGroup = 'created the group';
  static const activityUpdatedGroup = 'updated the group';
  static const activityArchivedGroup = 'archived the group';
  static const activityDeletedGroup = 'deleted the group';
  static const activityTurnedOnSimplify = 'turned on simplify debts in';
  static const activityTurnedOffSimplify = 'turned off simplify debts in';
  static const activityJoined = 'joined';
  static const activityLeft = 'left';
  static const activityRemoved = 'removed';
  static const activityMade = 'made';
  static const activityCommentedOn = 'commented on';
  static String activityTotal(String amount) => 'Total $amount';
  static String activityYouReceived(String amount) => 'You received $amount';
  static String activityYouGetBack(String amount) => 'You get back $amount';
  static String activityYouOwe(String amount) => 'You owe $amount';
  static const activityYouOweNothing = 'You do not owe anything';
  static const activityToday = 'Today';
  static const activityYesterday = 'Yesterday';
  static const markAllRead = 'Mark all read';
  static const unread = 'Unread';
  static const noActivityYet = 'No activity yet';
  static const noActivityHint =
      'Expenses, payments and group events will appear here.';
  static const couldNotLoadActivity = "Couldn't load activity";
  static const activityFilterAll = 'All';
  static const activityFilterExpenses = 'Expenses';
  static const activityFilterSettled = 'Payments';
  static const activityFilterGroups = 'Groups';

  // Account tab
  static const preferences = 'Preferences';
  static const tools = 'Tools';
  static const feedback = 'Feedback';
  static const editProfile = 'Edit profile';
  static const security = 'Security';
  static const appearance = 'Appearance';
  static const themeSystem = 'System default';
  static const themeLight = 'Light';
  static const themeDark = 'Dark';
  static const supportUsDonate = 'Support us / Donate';
  static const contactUs = 'Contact us';
  static const privacyPolicy = 'Privacy policy';
  static const termsOfService = 'Terms of service';
  static const logOut = 'Log out';

  // ── Group detail redesign (U3) ──
  // Expense / payment rows
  static String namePaid(String name, String amount) => '$name paid $amount';
  static String youPaidNameAmount(String name, String amount) =>
      'You paid $name $amount';
  static String namePaidYou(String name, String amount) =>
      '$name paid you $amount';
  static String namePaidName(String from, String to, String amount) =>
      '$from paid $to $amount';
  static const paymentAwaitingConfirmation = 'Waiting for confirmation';
  static const paymentNotReceived = 'Marked as not received';
  static const expenseNoBalance = 'no balance';
  static const noExpensesHereYet = 'No expenses here yet';
  static const noExpensesHereHint =
      'Add an expense to start splitting with this group.';
  static const addExpenseArchived = 'Add expense unavailable, group archived';
  // Header
  static String groupOverallOwed(String amount) =>
      'You are owed $amount overall';
  static String groupOverallOwe(String amount) => 'You owe $amount overall';
  static const groupAllSettled = 'You are all settled up in this group';
  static const groupExport = 'Export';
  static const groupRecurring = 'Recurring';
  static const groupSettings = 'Group settings';
  static const groupMoreOptions = 'More options';
  static const groupBack = 'Back';
  static String groupCoverOf(String name) => 'Cover of $name';
  // Balances screen
  static const balanceYou = 'You';
  static const balanceYouObject = 'you';
  static String balanceGetsBackTotal(String name, String amount) =>
      '$name gets back $amount in total';
  static String balanceOwesTotal(String name, String amount) =>
      '$name owes $amount in total';
  static String balanceYouGetBackTotal(String amount) =>
      'You get back $amount in total';
  static String balanceYouOweTotal(String amount) =>
      'You owe $amount in total';
  static String balanceIsSettled(String name) => '$name is settled up';
  static String balanceOwesTo(String from, String amount, String to) =>
      '$from owes $amount to $to';
  static String balanceYouOweTo(String amount, String to) =>
      'You owe $amount to $to';
  static const remindEllipsis = 'Remind…';
  static const balancePending = 'Payment pending';
  // Totals screen
  static const paymentsMade = 'Payments made';
  static const paymentsReceived = 'Payments received';
  static const totalChangeInBalance = 'Total change in balance';
  // Group settings screen
  static const groupMembers = 'Group members';
  static const addPeopleToGroup = 'Add people to group';
  static const advancedSettings = 'Advanced settings';
  static const editGroupDetails = 'Edit group';
  static const editGroupHint = 'Name and cover photo';
  static const leaveGroup = 'Leave group';
  static const deleteGroup = 'Delete group';
  static const memberGetsBack = 'gets back';
  static const memberOwes = 'owes';
  static const adminOnlySetting = 'Only the group admin can change this';

  // ── Expense & settle redesign (U4/U5) ──
  static const addAnExpense = 'Add an expense';
  static const withYouAnd = 'With you and:';
  static const chooseGroupOrFriend = 'Choose a group or friend';
  static const addExpenseTo = 'Add expense to';
  static const expenseGroupLocked =
      "An expense can't be moved to another group.";
  static const enterDescription = 'Enter a description';
  static const descriptionRequired = 'Add a description';
  static const amountMustBePositive = 'Enter an amount greater than 0';
  static const chooseCategory = 'Choose a category';
  static String paidSplitSentence(String paidBy, String split) =>
      'Paid by $paidBy and split $split.';
  static const paidByWord = 'Paid by';
  static const andSplitWord = 'and split';
  static const youLower = 'you';
  static const splitPillEqually = 'equally';
  static const splitPillExact = 'unequally';
  static const splitPillPercent = 'by percentages';
  static const splitPillShares = 'by shares';
  static const splitPillAdjustment = 'by adjustment';
  static const splitPillGroupDefault = 'by group default';
  static String changePayerLabel(String paidBy) =>
      'Paid by $paidBy. Tap to change who paid';
  static String changeSplitLabel(String split) =>
      'Split $split. Tap to change the split';
  static const saveLabel = 'Save';
  static const savingLabel = 'Saving';
  static String dateTapLabel(String date) => 'Date $date. Tap to change';
  static const addOrScanReceipt = 'Add or scan a receipt';
  static const addNotesLabel = 'Add notes';
  static const receiptAdded = 'Receipt added';
  static const splitOptions = 'Split options';
  static const splitTabEqually = 'Equally';
  static const splitTabExact = 'Exact';
  static const splitTabPercent = 'Percent';
  static const splitTabShares = 'Shares';
  static const splitTabAdjust = 'Adjust';
  static const splitHeadEqually = 'Split equally';
  static const splitHeadExact = 'Split by exact amounts';
  static const splitHeadPercent = 'Split by percentages';
  static const splitHeadShares = 'Split by shares';
  static const splitHeadAdjustment = 'Split by adjustment';
  static const splitDescEqually = 'Select which people owe an equal share.';
  static const splitDescExact = 'Specify exactly how much each person owes.';
  static const splitDescPercent =
      "Enter the percentage split that's fair for your situation.";
  static const splitDescShares =
      'Great for time-based splitting (2 nights → 2 shares) and splitting '
      'across families (family of 3 → 3 shares).';
  static String perPerson(String amount) => '$amount/person';
  static String peopleInSplit(int n) => n == 1 ? '(1 person)' : '($n people)';
  static String amountOfTotal(String part, String total) => '$part of $total';
  static String amountOverShort(String amount) => '$amount over';
  static String totalShares(String n) => '$n total shares';
  static String totalAmountShort(String amount) => '$amount total';
  static const selectAllShort = 'All';
  static const selectAtLeastOne = 'Select at least one person';
  static String personPaidAndOwes(String name, String paid, String owes) =>
      '$name paid $paid and owes $owes';
  static String personPaid(String name, String paid) => '$name paid $paid';
  static String personOwes(String name, String owes) => '$name owes $owes';
  static String youPaidAndOwe(String paid, String owe) =>
      'You paid $paid and owe $owe';
  static String youOweAmount(String owe) => 'You owe $owe';
  static String addedOnDate(String date) => 'Added on $date';
  static String updatedByOn(String name, String date) =>
      'Updated by $name on $date';
  static const deleteLabel = 'Delete';
  static const moreOptions = 'More options';
  static const showWorking = 'Show working';
  static const hideWorking = 'Hide working';
  static const viewReceipt = 'View receipt';
  static const recordAPayment = 'Record a payment';
  static String youPaidName(String name) => 'You paid $name';
  static const todayLabel = 'Today';
  static const methodLabel = 'Method';
  static const noteLabel = 'Note';
  static const pickGroupFirst = 'Pick a group first.';
  static const inWhichGroup = 'In which group?';
  static const noSharedGroups =
      "You don't share any groups with this person yet.";
  static const paymentAmountLabel = 'Amount paid';
  static const choosePayer = 'Choose payer';
  static const paymentDateToday =
      "Payments are recorded with today's date.";

  // ── Friend detail redesign ──
  static String friendOverallOwesYou(String name, String amount) =>
      '$name owes you $amount overall';
  static String friendOverallYouOwe(String name, String amount) =>
      'You owe $name $amount overall';
  static String friendInGroupOwesYou(String group, String name, String amount) =>
      'In $group, $name owes you $amount';
  static String friendInGroupYouOwe(String group, String name, String amount) =>
      'In $group, you owe $name $amount';
  static const friendNonGroupLower = 'non-group expenses';
  static const friendOpenGroup = 'Open group';
  static const friendNoSharedExpenses = 'No shared expenses yet';
  static String friendNoSharedExpensesHint(String name) =>
      'Add an expense to start splitting with $name.';
  static const friendSharedExpensesError = "Couldn't load shared expenses";
  static const friendLoadError = 'Failed to load friend details';
  static const friendNotFound = 'Friend not found';
  static const friendNotFoundHint =
      "You don't share any groups or balances with this person.";
  static const backToFriends = 'Back to friends';
  static const friendFallbackTitle = 'Friend';
  static String totalsPaidShareLine(String paid, String share) =>
      'Paid $paid · Share $share';

  // ── Payments history redesign ──
  static String historyOwesYouIn(String name, String amount, String group) =>
      '$name owes you $amount in $group';
  static String historyYouOweIn(String name, String amount, String group) =>
      'You owe $name $amount in $group';
  static String historySettledIn(String name, String group) =>
      'You and $name are settled up in $group';
  static String historySettledWith(String name) =>
      'You and $name are settled up';
  static String historyPendingFromMe(String amount, String name) =>
      'You paid $amount, waiting for $name to confirm';
  static String historyPendingFromThem(String name, String amount) =>
      '$name paid you $amount, waiting for you to confirm';
  static const historyCoveredByPending =
      'Your pending payment covers this balance';
  static const historyPaymentConfirmed = 'Confirmed';
  static const historyNoPayments = 'No payments yet';
  static String historyNoPaymentsHint(String name) =>
      'When you settle up with $name, payments will appear here.';
  static String historyBetween(String from, String to) =>
      'Money flows from $from to $to';

  // ── Scan receipt prompt ──
  static const scanReceiptTitle = 'Scan a receipt';
  static const scanReceiptHint =
      'Take a photo and we fill in the amount, date and description';
  static const addReceiptTitle = 'Add a receipt';
  static const addReceiptHint = 'Attach a photo of the bill';

  // ── Activity taps ──
  static const activityExpenseDeleted = 'This expense was deleted';
  static const activityGroupDeleted = 'This group was deleted';
  static const activityNotInGroup = "You're no longer in this group";

  // ── Record a payment button ──
  static const recordLabel = 'Record';

  // ── New-feature highlight ──
  static const newBadge = 'NEW';

  // ── Contacts access (iOS limited / off) ──
  static String contactsSharedCount(int n) =>
      'You shared $n contact${n == 1 ? '' : 's'} with KharchaSplit';
  static const contactsAddMore = 'Add more';
  static const contactsAllowAll = 'Allow all';
  static const contactsNoneSharedTitle = 'No contacts shared yet';
  static const contactsNoneSharedBody =
      'You chose to share only some contacts. Pick the friends you split with.';
  static const contactsAccessOffTitle = 'Contacts access is off';
  static const contactsAccessOffBody =
      'Turn on Contacts for KharchaSplit in Settings, or pick a friend below.';
  static const contactsChooseToShare = 'Choose contacts to share';
  static const openSettings = 'Open Settings';
  static const contactsPickOne = 'Pick a contact';
  static const contactsAllowAllInSettings = 'Allow all contacts in Settings';
  static const contactsOrTypeNumber =
      'You can also type a 10-digit number in the search box above.';
  static String contactPicked(String name) => 'Added $name';
  static const contactHasNoNumber = 'That contact has no phone number';
}
