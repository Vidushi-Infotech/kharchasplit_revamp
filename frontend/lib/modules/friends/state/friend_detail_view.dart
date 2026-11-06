import '../../../components/list/balance_tone.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/expense_model.dart';
import '../../groups/state/group_ledger.dart';
import 'friends_provider.dart';

/// Display name for a friend; invited people may not have one yet.
String friendDisplayName(String name) =>
    name.trim().isEmpty ? AppStrings.invitedMember : name.trim();

/// One overall line per currency under the friend's name: "Test Four owes
/// you ₹200.00 overall" / "You owe Test Four ₹50.00 overall". Empty map
/// (all settled) gives "You are all settled up with Test Four". Currencies
/// are never converted.
List<({String text, BalanceTone tone})> friendOverallLines(FriendBalance f) {
  final name = friendDisplayName(f.user.name);
  final byCurrency = f.netByCurrency;
  if (byCurrency.isEmpty) {
    return [
      (text: AppStrings.settledUpWith(name), tone: BalanceTone.settled),
    ];
  }
  return [
    for (final e in byCurrency.entries)
      (
        text: e.value > 0
            ? AppStrings.friendOverallOwesYou(name, _fmt(e.value, e.key))
            : AppStrings.friendOverallYouOwe(name, _fmt(e.value, e.key)),
        tone: BalanceTone.fromAmount(e.value),
      ),
  ];
}

/// Gray per-group line: "In Goa trip, Test F. owes you ₹200.00" / "In
/// non-group expenses, you owe Test F. ₹50.00".
String friendGroupLine(FriendGroupBalance g, String friendName) {
  final name = NameFormat.short(friendDisplayName(friendName));
  final group = g.isDirect ? AppStrings.friendNonGroupLower : g.groupName;
  final amount = _fmt(g.net, g.currency);
  return g.net > 0
      ? AppStrings.friendInGroupOwesYou(group, name, amount)
      : AppStrings.friendInGroupYouOwe(group, name, amount);
}

String _fmt(double v, String currency) =>
    CurrencyFormatter.format(v.abs(), currency: currency);

/// How a shared expense reads on the friend page. Tone and amount come
/// from [expenseRowView] (the group list's logic, multi-payer included),
/// so one tone drives both the label and the amount color.
class FriendExpenseRowView {
  const FriendExpenseRowView({
    required this.tone,
    required this.amount,
    required this.label,
    required this.subtitle,
  });

  final BalanceTone tone;
  final double amount;

  /// "you lent" / "you borrowed" / "not involved" / "no balance".
  final String label;

  /// "Goa trip · Test R. paid ₹900.00", or just the payer line for
  /// non-group expenses.
  final String subtitle;

  bool get showsAmount => tone == BalanceTone.owed || tone == BalanceTone.owe;
}

FriendExpenseRowView friendExpenseRowView(
  ExpenseModel expense,
  String? myId, {
  String? groupName,
}) {
  final view = expenseRowView(expense, myId);
  final label = view.tone == BalanceTone.settled
      ? AppStrings.expenseNoBalance
      : view.tone.expenseLabel;
  final group = groupName?.trim() ?? '';
  return FriendExpenseRowView(
    tone: view.tone,
    amount: view.amount,
    label: label,
    subtitle: group.isEmpty ? view.payerLine : '$group · ${view.payerLine}',
  );
}
