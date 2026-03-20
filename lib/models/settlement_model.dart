import 'package:equatable/equatable.dart';
import 'user_model.dart';

/// Settlement method enum
enum SettlementMethod {
  upi,
  cash,
  bankTransfer,
  other,
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
  final SettlementMethod method;
  final DateTime date;
  final String? note;
  final SettlementStatus status;
  final DateTime createdAt;

  const SettlementModel({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    this.currency = '₹',
    this.method = SettlementMethod.cash,
    required this.date,
    this.note,
    this.status = SettlementStatus.completed,
    required this.createdAt,
  });

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
    );
  }

  /// Get human-readable method name
  String get methodName {
    switch (method) {
      case SettlementMethod.upi:
        return 'UPI';
      case SettlementMethod.cash:
        return 'Cash';
      case SettlementMethod.bankTransfer:
        return 'Bank Transfer';
      case SettlementMethod.other:
        return 'Other';
    }
  }

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
      ];
}
