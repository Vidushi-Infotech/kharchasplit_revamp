/// One month of the Personal mode's Insights (GET
/// /personal-expenses/summary): spending by category and by day, compared
/// with the month before, and a six-month trend.
class PersonalSummary {
  const PersonalSummary({
    required this.month,
    required this.spent,
    required this.income,
    required this.previousSpent,
    required this.previousIncome,
    required this.categories,
    required this.incomeCategories,
    required this.daily,
    required this.trend,
  });

  /// First day of the month.
  final DateTime month;
  final double spent;
  final double income;
  final double previousSpent;
  final double previousIncome;

  /// Spending per category, biggest first; includes categories that only
  /// had spending last month (amount 0).
  final List<CategorySpend> categories;
  final List<CategorySpend> incomeCategories;

  /// One entry per day of the month.
  final List<DayFlow> daily;

  /// Oldest first, ending with [month].
  final List<MonthFlow> trend;

  bool get isEmpty => spent == 0 && income == 0;

  /// Spending change against last month as a fraction (0.25 = 25% more),
  /// or null when last month had none to compare with.
  double? get spentChange =>
      previousSpent == 0 ? null : (spent - previousSpent) / previousSpent;

  factory PersonalSummary.fromJson(Map<String, dynamic> json) {
    return PersonalSummary(
      month: _month(json['month'] as String),
      spent: _num(json['spent']),
      income: _num(json['income']),
      previousSpent: _num(json['previousSpent']),
      previousIncome: _num(json['previousIncome']),
      categories: _list(json['categories'], CategorySpend.fromJson),
      incomeCategories: _list(json['incomeCategories'], CategorySpend.fromJson),
      daily: _list(json['daily'], DayFlow.fromJson),
      trend: _list(json['trend'], MonthFlow.fromJson),
    );
  }
}

class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.amount,
    this.previousAmount = 0,
  });

  final String category;
  final double amount;
  final double previousAmount;

  factory CategorySpend.fromJson(Map<String, dynamic> json) => CategorySpend(
    category: (json['category'] as String?) ?? 'other',
    amount: _num(json['amount']),
    previousAmount: _num(json['previousAmount']),
  );
}

class DayFlow {
  const DayFlow({required this.day, required this.spent, required this.income});

  final DateTime day;
  final double spent;
  final double income;

  factory DayFlow.fromJson(Map<String, dynamic> json) => DayFlow(
    day: DateTime.parse(json['day'] as String),
    spent: _num(json['spent']),
    income: _num(json['income']),
  );
}

class MonthFlow {
  const MonthFlow({
    required this.month,
    required this.spent,
    required this.income,
  });

  final DateTime month;
  final double spent;
  final double income;

  factory MonthFlow.fromJson(Map<String, dynamic> json) => MonthFlow(
    month: _month(json['month'] as String),
    spent: _num(json['spent']),
    income: _num(json['income']),
  );
}

DateTime _month(String yyyyMm) => DateTime.parse('$yyyyMm-01');

double _num(dynamic v) => v is num
    ? v.toDouble()
    : v is String
    ? double.tryParse(v) ?? 0
    : 0;

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) =>
    raw is List
    ? raw.whereType<Map<String, dynamic>>().map(parse).toList()
    : [];
