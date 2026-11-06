/// How often a bill comes back (same names as the server's).
enum BillFrequency {
  weekly,
  biweekly,
  monthly,
  yearly;

  static BillFrequency parse(String? name) => values.firstWhere(
    (f) => f.name == name,
    orElse: () => BillFrequency.monthly,
  );
}

/// Where a bill stands: past its due date, inside its reminder window
/// (today included), or later.
enum BillStatus {
  overdue,
  due,
  upcoming;

  static BillStatus parse(String? name) => values.firstWhere(
    (s) => s.name == name,
    orElse: () => BillStatus.upcoming,
  );
}

/// A Personal mode bill (GET /personal-bills): a repeating amount with the
/// due date it's waiting on. Paying it adds an expense and moves it on.
class PersonalBill {
  const PersonalBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.nextDue,
    required this.daysLeft,
    required this.status,
    this.accountId,
    this.remindDays = 2,
  });

  final String id;
  final String name;
  final double amount;
  final String category;
  final String? accountId;
  final BillFrequency frequency;
  final DateTime nextDue;

  /// Days until [nextDue]; negative when overdue.
  final int daysLeft;
  final BillStatus status;
  final int remindDays;

  factory PersonalBill.fromJson(Map<String, dynamic> json) => PersonalBill(
    id: json['id'] as String,
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    category: (json['category'] as String?) ?? 'utilities',
    accountId: json['accountId'] as String?,
    frequency: BillFrequency.parse(json['frequency'] as String?),
    nextDue: DateTime.parse(json['nextDue'] as String),
    daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
    status: BillStatus.parse(json['status'] as String?),
    remindDays: (json['remindDays'] as num?)?.toInt() ?? 2,
  );
}
