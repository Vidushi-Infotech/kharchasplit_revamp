import 'package:equatable/equatable.dart';
import '../core/utils/currency_formatter.dart';
import 'user_model.dart';

/// How a payment was made. Mirrors backend `settlements.method`
/// (migration 018); [apiValue] is the wire value.
enum SettlementMethod {
  upi('upi'),
  cash('cash'),
  bankTransfer('bank_transfer'),
  other('other');

  const SettlementMethod(this.apiValue);
  final String apiValue;

  String get label => switch (this) {
        SettlementMethod.upi => 'UPI',
        SettlementMethod.cash => 'Cash',
        SettlementMethod.bankTransfer => 'Bank transfer',
        SettlementMethod.other => 'Other',
      };

  /// Null for unknown / missing values (rows recorded before the column
  /// existed, or by older app builds).
  static SettlementMethod? fromApi(Object? value) {
    for (final m in values) {
      if (m.apiValue == value) return m;
    }
    return null;
  }
}

/// Settlement status enum
enum SettlementStatus {
  pending,
  completed,
  failed,
}

/// Settlement model representing a payment between two users
class SettlementModel extends Equatable {
  final String id;
  final UserModel fromUser;
  final UserModel toUser;
  final double amount;
  final String currency;
  /// Null when the payer didn't record a method (older rows / app builds).
  final SettlementMethod? method;
  final DateTime date;
  final String? note;
  final SettlementStatus status;
  final DateTime createdAt;

  /// True only for server status 'paid' — the one status the backend
  /// ledger counts (services/ledger.js). Legacy 'completed' rows display
  /// as completed but don't move balances.
  final bool countsTowardBalance;

  const SettlementModel({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    this.currency = '₹',
    this.method,
    required this.date,
    this.note,
    this.status = SettlementStatus.completed,
    required this.createdAt,
    this.countsTowardBalance = true,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    UserModel _user(String key, String nameKey) {
      final maybe = json[key];
      if (maybe is Map<String, dynamic>) return UserModel.fromJson(maybe);
      return UserModel(
        id: (json[key] ?? '') as String,
        name: (json[nameKey] as String?) ?? 'Unknown',
        email: '',
        phone: '',
        createdAt: DateTime.now(),
      );
    }

    final created = json['createdAt'] ?? json['created_at'];
    final settledAt = json['settledAt'] ?? json['settled_at'] ?? created;
    final statusRaw = (json['status'] as String?) ?? 'completed';

    return SettlementModel(
      id: json['id'] as String,
      fromUser: json['fromUser'] is Map<String, dynamic>
          ? UserModel.fromJson(json['fromUser'] as Map<String, dynamic>)
          : _user('from_user_id', 'from_user_name'),
      toUser: json['toUser'] is Map<String, dynamic>
          ? UserModel.fromJson(json['toUser'] as Map<String, dynamic>)
          : _user('to_user_id', 'to_user_name'),
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: CurrencyFormatter.symbolFor(
          (json['currency'] as String?) ?? 'INR'),
      method: SettlementMethod.fromApi(json['method']),
      date: settledAt is String ? DateTime.parse(settledAt) : DateTime.now(),
      note: json['notes'] as String?,
      status: statusRaw == 'pending'
          ? SettlementStatus.pending
          : statusRaw == 'failed'
              ? SettlementStatus.failed
              : SettlementStatus.completed,
      createdAt:
          created is String ? DateTime.parse(created) : DateTime.now(),
      countsTowardBalance: json['status'] == null || statusRaw == 'paid',
    );
  }

  SettlementModel copyWith({
    String? id,
    UserModel? fromUser,
    UserModel? toUser,
    double? amount,
    String? currency,
    SettlementMethod? method,
    DateTime? date,
    String? note,
    SettlementStatus? status,
    DateTime? createdAt,
    bool? countsTowardBalance,
  }) {
    return SettlementModel(
      id: id ?? this.id,
      fromUser: fromUser ?? this.fromUser,
      toUser: toUser ?? this.toUser,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      date: date ?? this.date,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      countsTowardBalance: countsTowardBalance ?? this.countsTowardBalance,
    );
  }

  /// Human-readable method name; null when no method was recorded.
  String? get methodName => method?.label;

  /// Get human-readable status name
  String get statusName {
    switch (status) {
      case SettlementStatus.pending:
        return 'Pending';
      case SettlementStatus.completed:
        return 'Completed';
      case SettlementStatus.failed:
        return 'Failed';
    }
  }

  @override
  List<Object?> get props => [
        id,
        fromUser,
        toUser,
        amount,
        currency,
        method,
        date,
        note,
        status,
        createdAt,
        countsTowardBalance,
      ];
}
