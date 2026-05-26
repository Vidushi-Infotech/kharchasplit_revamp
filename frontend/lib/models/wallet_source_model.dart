import 'package:equatable/equatable.dart';

enum WalletSourceType { cash, bank }

/// A single funding source for personal expenses (e.g. "Cash" or "HDFC ****1234").
/// Stored locally per-user — not synced to the backend.
class WalletSource extends Equatable {
  const WalletSource({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });

  final String id;
  final String name;
  final WalletSourceType type;
  final double balance;

  WalletSource copyWith({
    String? id,
    String? name,
    WalletSourceType? type,
    double? balance,
  }) {
    return WalletSource(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
    );
  }

  factory WalletSource.fromJson(Map<String, dynamic> json) {
    return WalletSource(
      id: json['id'] as String,
      name: json['name'] as String,
      type: (json['type'] as String) == 'bank'
          ? WalletSourceType.bank
          : WalletSourceType.cash,
      balance: (json['balance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type == WalletSourceType.bank ? 'bank' : 'cash',
        'balance': balance,
      };

  @override
  List<Object?> get props => [id, name, type, balance];
}
