/// Money moved between two of the user's Personal accounts (e.g. an ATM
/// withdrawal: bank → cash). Doesn't count as spending or income.
class PersonalTransfer {
  const PersonalTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.date,
    this.note,
  });

  final String id;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final DateTime date;
  final String? note;

  factory PersonalTransfer.fromJson(Map<String, dynamic> json) =>
      PersonalTransfer(
        id: json['id'] as String,
        fromAccountId: json['fromAccountId'] as String,
        toAccountId: json['toAccountId'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String).toLocal(),
        note: json['note'] as String?,
      );
}
