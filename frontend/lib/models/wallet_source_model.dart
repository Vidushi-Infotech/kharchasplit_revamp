import 'package:equatable/equatable.dart';

/// Kinds of account. Card and wallet (UPI apps, Paytm…) came with server
/// accounts; the phone-only wallet only ever stored cash and bank.
enum WalletSourceType {
  cash,
  bank,
  card,
  wallet;

  static WalletSourceType parse(String? name) => values.firstWhere(
    (t) => t.name == name,
    orElse: () => WalletSourceType.cash,
  );
}

/// A single account for personal entries (e.g. "Cash" or "HDFC ****1234").
/// With the `personalAccounts` flag it lives on the server (its balance
/// computed there); before that, only on the phone. A credit card's
/// balance is negative while money is owed on it.
class WalletSource extends Equatable {
  const WalletSource({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.entryCount,
  });

  final String id;
  final String name;
  final WalletSourceType type;
  final double balance;

  /// Entries tagged to it (server accounts only).
  final int? entryCount;

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
      entryCount: entryCount,
    );
  }

  factory WalletSource.fromJson(Map<String, dynamic> json) {
    return WalletSource(
      id: json['id'] as String,
      name: json['name'] as String,
      type: WalletSourceType.parse(json['type'] as String?),
      balance: (json['balance'] as num).toDouble(),
      entryCount: json['entryCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'balance': balance,
  };

  @override
  List<Object?> get props => [id, name, type, balance, entryCount];
}
