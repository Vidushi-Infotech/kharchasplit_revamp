import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import 'friends_provider.dart';

/// Gray lines under a friend's name on the Friends list, one per group
/// with an open balance (largest first, the server's order):
/// "In Goa trip: Test F. owes you ₹50" / "In Flat: you owe Test F. ₹20" /
/// "Non-group expenses: you owe ₹10". At most [max] lines, then
/// "Plus N more groups".
List<String> friendBalanceLines(FriendBalance f, {int max = 2}) {
  final name = NameFormat.short(f.user.name);
  final open = f.groups.where((g) => g.net.abs() > 0.005).toList();
  final lines = <String>[
    for (final g in open.take(max))
      _line(
        g,
        name,
        CurrencyFormatter.format(g.net.abs(), currency: g.currency),
      ),
  ];
  if (open.length > max) {
    lines.add(AppStrings.plusMoreGroups(open.length - max));
  }
  return lines;
}

String _line(FriendGroupBalance g, String name, String amount) {
  if (g.isDirect) {
    return g.net > 0
        ? AppStrings.nonGroupNameOwesYou(name, amount)
        : AppStrings.nonGroupYouOwe(amount);
  }
  return g.net > 0
      ? AppStrings.inGroupNameOwesYou(g.groupName, name, amount)
      : AppStrings.inGroupYouOweName(g.groupName, name, amount);
}
