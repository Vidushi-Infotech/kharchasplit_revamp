import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/activity_model.dart';

/// One piece of an activity sentence. Names (people, expenses, groups) are
/// [bold]; the glue words between them are not.
class ActivitySpan {
  const ActivitySpan(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is ActivitySpan && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => bold ? '*$text*' : text;
}

/// Direction of the optional money line under the sentence.
enum ActivityAmountTone { neutral, paid, received }

/// What an Activity row says: the sentence, an optional money line
/// ("You paid ₹350.00" / "Total ₹2,585.00") and who did it.
class ActivitySentence {
  const ActivitySentence({
    required this.spans,
    required this.actorName,
    this.amountLine,
    this.amountTone = ActivityAmountTone.neutral,
  });

  final List<ActivitySpan> spans;

  /// For the avatar badge; "You" for your own actions.
  final String actorName;
  final String? amountLine;
  final ActivityAmountTone amountTone;

  /// The sentence as plain text (screen readers, tests).
  String get text => spans.map((s) => s.text).join();
}

/// Builds Splitwise-style sentences — `You added "Dinner" in "Goa trip".`
/// — from a feed row. Only uses what the server logged; nothing is
/// guessed. Expense rows say what it means for you ("You owe ₹X" /
/// "You get back ₹X") when the server sent your net, else the total.
ActivitySentence buildActivitySentence(
  ActivityModel a, {
  required String? myUserId,
  String? myName,
}) {
  final m = a.metadata;
  final isMe = myUserId != null && a.actorId == myUserId;
  final rawActor = a.actorUser?.name.trim() ?? '';
  final actor = isMe
      ? AppStrings.activityYou
      : (rawActor.isEmpty ? AppStrings.activitySomeone : rawActor);

  String str(String key) => (m[key] as Object?)?.toString().trim() ?? '';
  final group = str('groupName').isNotEmpty
      ? str('groupName')
      : (a.group?.name.trim() ?? '');
  final expense = str('expenseDescription');

  /// Another person's name, or "you" when it's the viewer.
  String person(String name) {
    if (name.isEmpty) return AppStrings.activitySomeone;
    final mine = myName?.trim() ?? '';
    if (mine.isNotEmpty && name == mine) return AppStrings.activityYouLower;
    return name;
  }

  final spans = <ActivitySpan>[ActivitySpan(actor, bold: true)];
  void word(String w) => spans.add(ActivitySpan(' $w'));
  void name(String n) => spans.add(ActivitySpan(' $n', bold: true));
  void quoted(String n) => spans.add(ActivitySpan(' "$n"', bold: true));
  void inGroup([String prep = AppStrings.activityIn]) {
    if (group.isEmpty) return;
    word(prep);
    quoted(group);
  }

  void expenseName() =>
      expense.isEmpty ? word(AppStrings.activityAnExpense) : quoted(expense);

  String? amountLine;
  var tone = ActivityAmountTone.neutral;
  final amount = _amount(m['amount']);
  final money = amount == null
      ? null
      : CurrencyFormatter.format(
          amount,
          currency: str('currency').isEmpty ? 'INR' : str('currency'),
        );

  switch (a.type) {
    case ActivityType.expenseAdded:
      word(AppStrings.activityAdded);
      expenseName();
      inGroup();
      (amountLine, tone) = _expenseLine(a, money, str('currency'));
    case ActivityType.expenseEdited:
      word(AppStrings.activityUpdated);
      expenseName();
      inGroup();
      (amountLine, tone) = _expenseLine(a, money, str('currency'));
    case ActivityType.expenseDeleted:
      word(AppStrings.activityDeleted);
      expenseName();
      inGroup(AppStrings.activityFrom);
    case ActivityType.settled:
      // Logged under the payer: "<payer> paid <payee>".
      word(AppStrings.activityPaid);
      name(person(str('toName')));
      inGroup();
      if (money != null) {
        if (isMe) {
          amountLine = AppStrings.youPaidAmount(money);
          tone = ActivityAmountTone.paid;
        } else if (person(str('toName')) == AppStrings.activityYouLower) {
          amountLine = AppStrings.activityYouReceived(money);
          tone = ActivityAmountTone.received;
        }
      }
    case ActivityType.settlementConfirmed:
      // Logged under the payee.
      word(AppStrings.activityConfirmedPaymentFrom);
      name(person(str('fromName')));
      inGroup();
      if (money != null && isMe) {
        amountLine = AppStrings.activityYouReceived(money);
        tone = ActivityAmountTone.received;
      }
    case ActivityType.settlementDeleted:
      word(AppStrings.activityDeletedPaymentFrom);
      name(person(str('fromName')));
      word(AppStrings.activityTo);
      name(person(str('toName')));
      inGroup();
    case ActivityType.groupCreated:
      word(AppStrings.activityCreatedGroup);
      if (group.isNotEmpty) quoted(group);
    case ActivityType.groupUpdated:
      final changes = m['changes'];
      final simplify = changes is Map ? changes['simplifyDebts'] : null;
      if (simplify is bool) {
        word(
          simplify
              ? AppStrings.activityTurnedOnSimplify
              : AppStrings.activityTurnedOffSimplify,
        );
        if (group.isNotEmpty) quoted(group);
      } else {
        word(AppStrings.activityUpdatedGroup);
        if (group.isNotEmpty) quoted(group);
      }
    case ActivityType.groupArchived:
      word(AppStrings.activityArchivedGroup);
      if (group.isNotEmpty) quoted(group);
    case ActivityType.groupDeleted:
      word(AppStrings.activityDeletedGroup);
      if (group.isNotEmpty) quoted(group);
    case ActivityType.memberAdded:
      final member = str('memberName');
      if (member.isEmpty || member == rawActor) {
        word(AppStrings.activityJoined);
        if (group.isNotEmpty) quoted(group);
      } else {
        word(AppStrings.activityAdded);
        name(person(member));
        inGroup(AppStrings.activityTo);
      }
    case ActivityType.memberRemoved:
      final member = str('memberName');
      if (member.isEmpty || member == rawActor) {
        word(AppStrings.activityLeft);
        if (group.isNotEmpty) quoted(group);
      } else {
        word(AppStrings.activityRemoved);
        name(person(member));
        inGroup(AppStrings.activityFrom);
      }
    case ActivityType.memberRoleUpdated:
      word(AppStrings.activityMade);
      name(person(str('memberName')));
      if (str('newRole').isNotEmpty) word(str('newRole'));
      inGroup();
    case ActivityType.commentAdded:
      word(AppStrings.activityCommentedOn);
      expenseName();
      inGroup();
    case ActivityType.other:
      // Unknown event: the server's own wording, unbolded.
      return ActivitySentence(
        spans: [ActivitySpan(a.description)],
        actorName: actor,
      );
  }
  spans.add(const ActivitySpan('.'));
  return ActivitySentence(
    spans: spans,
    actorName: actor,
    amountLine: amountLine,
    amountTone: tone,
  );
}

/// "Today, 6:30 PM" / "Yesterday, 6:30 PM" / "Oct 18, 6:30 PM" /
/// "Oct 18, 2025, 6:30 PM".
String activityTimeLabel(DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(local.year, local.month, local.day);
  final clock = DateFormat('h:mm a').format(local);
  if (day == today) return '${AppStrings.activityToday}, $clock';
  if (day == today.subtract(const Duration(days: 1))) {
    return '${AppStrings.activityYesterday}, $clock';
  }
  final date = local.year == n.year
      ? DateFormat('MMM d').format(local)
      : DateFormat('MMM d, yyyy').format(local);
  return '$date, $clock';
}

/// Server amounts arrive as numbers or NUMERIC strings ("1000.00").
double? _amount(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

/// Money line for an expense row: your side when the server sent your net
/// ([ActivityModel.yourNet]), else the expense total.
(String?, ActivityAmountTone) _expenseLine(
  ActivityModel a,
  String? total,
  String currency,
) {
  final net = a.yourNet;
  if (net == null) {
    return (
      total == null ? null : AppStrings.activityTotal(total),
      ActivityAmountTone.neutral,
    );
  }
  final money = CurrencyFormatter.format(
    net.abs(),
    currency: currency.isEmpty ? 'INR' : currency,
  );
  if (net > 0.004) {
    return (AppStrings.activityYouGetBack(money), ActivityAmountTone.received);
  }
  if (net < -0.004) {
    return (AppStrings.activityYouOwe(money), ActivityAmountTone.paid);
  }
  return (AppStrings.activityYouOweNothing, ActivityAmountTone.neutral);
}
