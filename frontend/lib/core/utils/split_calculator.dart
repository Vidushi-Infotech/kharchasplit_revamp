import 'package:kharchasplit/models/models.dart';

/// Split calculator utility
/// Handles all split types: equal, exact, percentage, shares
/// Ensures no paisa is lost in rounding (critical for finance apps)
class SplitCalculator {
  /// Calculate equal split
  /// Divides amount equally among members
  /// Adds remainder (paisa) to first person
  static List<SplitModel> calculateEqual({
    required double amount,
    required List<UserModel> members,
    Map<String, double>? paidByMap,
  }) {
    if (members.isEmpty) return [];

    final amountInPaisa = (amount * 100).round();
    final perPersonPaisa = amountInPaisa ~/ members.length;
    final remainderPaisa = amountInPaisa % members.length;

    final splits = <SplitModel>[];

    for (int i = 0; i < members.length; i++) {
      final share = (perPersonPaisa + (i == 0 ? remainderPaisa : 0)) / 100;
      final paid = paidByMap?[members[i].id] ?? 0;

      splits.add(
        SplitModel(
          userId: members[i].id,
          userName: members[i].name,
          userAvatarUrl: members[i].avatarUrl,
          owedShare: share,
          paidShare: paid,
          percentage: 100 / members.length,
        ),
      );
    }

    return splits;
  }

  /// Calculate exact split
  /// Validates that sum equals total amount
  static List<SplitModel> calculateExact({
    required double amount,
    required List<UserModel> members,
    required Map<String, double> splitAmounts,
  }) {
    if (members.isEmpty) return [];

    // Validate sum equals amount
    final totalSplit = splitAmounts.values.fold(0.0, (sum, val) => sum + val);
    if ((totalSplit - amount).abs() > 0.01) {
      throw Exception(
        'Split amounts (₹${totalSplit.toStringAsFixed(2)}) must equal total (₹${amount.toStringAsFixed(2)})',
      );
    }

    final splits = <SplitModel>[];

    for (final member in members) {
      final owedShare = splitAmounts[member.id] ?? 0;

      splits.add(
        SplitModel(
          userId: member.id,
          userName: member.name,
          userAvatarUrl: member.avatarUrl,
          owedShare: owedShare,
          paidShare: 0,
          percentage: (owedShare / amount * 100).isFinite
              ? owedShare / amount * 100
              : 0,
        ),
      );
    }

    return splits;
  }

  /// Calculate percentage split
  /// Validates that percentages sum to 100%
  static List<SplitModel> calculatePercentage({
    required double amount,
    required List<UserModel> members,
    required Map<String, double> percentages,
  }) {
    if (members.isEmpty) return [];

    // Validate percentages sum to 100
    final totalPercentage = percentages.values.fold(
      0.0,
      (sum, val) => sum + val,
    );
    if ((totalPercentage - 100).abs() > 0.01) {
      throw Exception(
        'Percentages must sum to 100%, got ${totalPercentage.toStringAsFixed(1)}%',
      );
    }

    final splits = <SplitModel>[];
    var allocatedAmount = 0.0;

    for (int i = 0; i < members.length; i++) {
      final percentage = percentages[members[i].id] ?? 0;
      final share = (percentage / 100) * amount;

      // Adjust last member to ensure total equals amount (handle rounding)
      final finalShare = i == members.length - 1
          ? amount - allocatedAmount
          : share;
      allocatedAmount += share;

      splits.add(
        SplitModel(
          userId: members[i].id,
          userName: members[i].name,
          userAvatarUrl: members[i].avatarUrl,
          owedShare: finalShare,
          paidShare: 0,
          percentage: percentage,
        ),
      );
    }

    return splits;
  }

  /// Calculate shares split
  /// Each person gets amount per share
  static List<SplitModel> calculateShares({
    required double amount,
    required List<UserModel> members,
    required Map<String, int> shares,
  }) {
    if (members.isEmpty) return [];

    final totalShares = shares.values.fold(0, (sum, val) => sum + val);
    if (totalShares == 0) {
      throw Exception('Total shares must be greater than 0');
    }

    final amountPerShare = amount / totalShares;
    final splits = <SplitModel>[];

    for (final member in members) {
      final memberShares = shares[member.id] ?? 0;
      final owedShare = memberShares * amountPerShare;

      splits.add(
        SplitModel(
          userId: member.id,
          userName: member.name,
          userAvatarUrl: member.avatarUrl,
          owedShare: owedShare,
          paidShare: 0,
          percentage: (memberShares / totalShares * 100).isFinite
              ? memberShares / totalShares * 100
              : 0,
        ),
      );
    }

    return splits;
  }

  /// Simplify debts using greedy algorithm
  /// Minimizes number of transactions needed to settle all debts
  static List<Map<String, dynamic>> simplifyDebts(List<SplitModel> splits) {
    // Calculate net balance for each person
    final balances = <String, double>{};

    for (final split in splits) {
      balances[split.userId] = (balances[split.userId] ?? 0) + split.balance;
    }

    // Remove settled accounts
    balances.removeWhere((_, balance) => balance.abs() < 0.01);

    final debts = <Map<String, dynamic>>[];

    while (balances.isNotEmpty) {
      // Find person with maximum debt and maximum credit
      final maxDebtor = balances.entries.reduce(
        (a, b) => a.value < b.value ? a : b,
      );
      final maxCreditor = balances.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      if (maxDebtor.value.abs() < 0.01 || maxCreditor.value < 0.01) {
        break;
      }

      // Settle as much as possible between them
      final amount = (maxDebtor.value.abs() < maxCreditor.value)
          ? maxDebtor.value.abs()
          : maxCreditor.value;

      debts.add({
        'from': maxDebtor.key,
        'to': maxCreditor.key,
        'amount': amount,
      });

      balances[maxDebtor.key] = maxDebtor.value + amount;
      balances[maxCreditor.key] = maxCreditor.value - amount;

      balances.removeWhere((_, balance) => balance.abs() < 0.01);
    }

    return debts;
  }

  /// Validate that total split equals expense amount
  static bool validateSplit(List<SplitModel> splits, double totalAmount) {
    final total = splits.fold(0.0, (sum, split) => sum + split.owedShare);
    return (total - totalAmount).abs() < 0.01;
  }

  /// Round to nearest paisa (2 decimal places)
  /// Ensures financial accuracy
  static double roundToPaisa(double value) {
    return (value * 100).round() / 100;
  }

  /// Rupees → whole paise. All exact money checks compare paise, never
  /// doubles (the server rejects a split that is off by even one paisa).
  static int toPaise(double rupees) => (rupees * 100).round();

  /// Splits [totalPaise] in proportion to [weights] (equal = all 1s,
  /// percentages, shares). Each person gets their floored share and the
  /// leftover paise go to the first person with a non-zero weight — the same
  /// rule as [calculateEqual] — so the result always sums to [totalPaise].
  /// All zeros when no weight is positive.
  static List<int> allocatePaise(int totalPaise, List<double> weights) {
    final totalWeight = weights.fold<double>(0, (s, w) => s + (w > 0 ? w : 0));
    if (totalWeight <= 0) return List.filled(weights.length, 0);
    final out = [
      for (final w in weights)
        // The epsilon keeps 4999.9999… (double noise) from flooring to 4999.
        w > 0 ? (totalPaise * w / totalWeight + 1e-6).floor() : 0,
    ];
    final first = weights.indexWhere((w) => w > 0);
    out[first] += totalPaise - out.fold<int>(0, (s, v) => s + v);
    return out;
  }

  /// "By adjustment": everyone owes an equal part of what is left after the
  /// adjustments, plus their own adjustment —
  /// `(total − Σadjustments) / n + adjustment_i`, in paise. The equal part
  /// is floored and its remainder goes to the first person, as in
  /// [calculateEqual]. Always sums to [totalPaise]; an entry can come out
  /// negative when the adjustments are larger than the total (callers treat
  /// that as an invalid split).
  static List<int> adjustmentPaise(int totalPaise, List<int> adjustments) {
    final n = adjustments.length;
    if (n == 0) return const [];
    final base = totalPaise - adjustments.fold<int>(0, (s, a) => s + a);
    // Dart's % is never negative for a positive divisor, so this floors even
    // when the adjustments exceed the total.
    final remainder = base % n;
    final perHead = (base - remainder) ~/ n;
    return [
      for (var i = 0; i < n; i++)
        perHead + (i == 0 ? remainder : 0) + adjustments[i],
    ];
  }
}
