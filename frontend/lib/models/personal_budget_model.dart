/// Personal mode budgets (GET /personal-budgets): a monthly limit per
/// expense category, or for the whole month ([BudgetStatus.total]), with
/// what's been spent against it this month.
class BudgetStatus {
  const BudgetStatus({
    required this.category,
    required this.amount,
    required this.spent,
  });

  /// The category id of the whole month's budget.
  static const total = 'total';

  final String category;
  final double amount;
  final double spent;

  bool get isTotal => category == total;

  /// Share of the budget used (1.0 = all of it, above 1 = over).
  double get used => amount > 0 ? spent / amount : 0;

  double get left => amount - spent;

  BudgetLevel get level => used >= 1
      ? BudgetLevel.over
      : used >= BudgetLevel.nearShare
      ? BudgetLevel.near
      : BudgetLevel.fine;

  factory BudgetStatus.fromJson(Map<String, dynamic> json) => BudgetStatus(
    category: json['category'] as String,
    amount: _num(json['amount']),
    spent: _num(json['spent']),
  );
}

/// How close a budget is to its limit: the colour of its bar and when an
/// alert goes out.
enum BudgetLevel {
  fine,
  near,
  over;

  /// From this share of the budget it's "near" (and alerts).
  static const nearShare = 0.8;
}

class BudgetsOverview {
  const BudgetsOverview({
    required this.month,
    required this.totalSpent,
    required this.budgets,
    required this.spent,
  });

  final DateTime month;
  final double totalSpent;
  final List<BudgetStatus> budgets;

  /// Spending this month per category, budgeted or not.
  final Map<String, double> spent;

  BudgetStatus? get total => budgets.where((b) => b.isTotal).firstOrNull;

  List<BudgetStatus> get categories =>
      budgets.where((b) => !b.isTotal).toList()
        ..sort((a, b) => b.used.compareTo(a.used));

  BudgetStatus? of(String category) =>
      budgets.where((b) => b.category == category).firstOrNull;

  factory BudgetsOverview.fromJson(Map<String, dynamic> json) {
    final spentList = json['spent'] is List ? json['spent'] as List : const [];
    return BudgetsOverview(
      month: DateTime.parse('${json['month']}-01'),
      totalSpent: _num(json['totalSpent']),
      budgets: (json['budgets'] is List ? json['budgets'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(BudgetStatus.fromJson)
          .toList(),
      spent: {
        for (final s in spentList.whereType<Map<String, dynamic>>())
          s['category'] as String: _num(s['spent']),
      },
    );
  }
}

/// A budget that just crossed into [level] (near or over) because of a new
/// expense.
class BudgetAlert {
  const BudgetAlert({required this.budget, required this.level});

  final BudgetStatus budget;
  final BudgetLevel level;
}

/// The alerts an expense in [category] set off, going from [before] to
/// [after]: its category budget and the month's total, each only when it
/// moved up a level (so one alert at 80% and one at 100%, not one per
/// expense). The most serious first.
List<BudgetAlert> budgetAlerts(
  BudgetsOverview? before,
  BudgetsOverview after,
  String category,
) {
  final alerts = <BudgetAlert>[];
  for (final id in [category, BudgetStatus.total]) {
    final now = after.of(id);
    if (now == null || now.level == BudgetLevel.fine) continue;
    final was = before?.of(id);
    if (was != null &&
        was.amount == now.amount &&
        was.level.index >= now.level.index) {
      continue;
    }
    alerts.add(BudgetAlert(budget: now, level: now.level));
  }
  alerts.sort((a, b) => b.level.index.compareTo(a.level.index));
  return alerts;
}

double _num(dynamic v) => v is num
    ? v.toDouble()
    : v is String
    ? double.tryParse(v) ?? 0
    : 0;
