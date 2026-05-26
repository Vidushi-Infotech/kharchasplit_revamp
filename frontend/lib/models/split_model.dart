import 'package:equatable/equatable.dart';

/// Split model representing how an expense is split among members
class SplitModel extends Equatable {
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final double owedShare;
  final double paidShare;
  final double percentage;
  final double shares;
  final bool isSettled;

  const SplitModel({
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.owedShare,
    this.paidShare = 0,
    this.percentage = 0,
    this.shares = 0,
    this.isSettled = false,
  });

  factory SplitModel.fromJson(Map<String, dynamic> json) {
    return SplitModel(
      userId: (json['userId'] ?? json['user_id'] ?? '') as String,
      userName:
          (json['userName'] ?? json['user_name'] ?? json['name'] ?? '') as String,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      owedShare: _parseAmount(json['owedShare'] ?? json['amount']),
      paidShare: _parseAmount(json['paidShare']),
      percentage: _parseAmount(json['percentage']),
      shares: _parseAmount(json['shares']),
      isSettled: (json['isSettled'] ?? json['is_settled'] ?? false) as bool,
    );
  }

  static double _parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  SplitModel copyWith({
    String? userId,
    String? userName,
    String? userAvatarUrl,
    double? owedShare,
    double? paidShare,
    double? percentage,
    double? shares,
    bool? isSettled,
  }) {
    return SplitModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      owedShare: owedShare ?? this.owedShare,
      paidShare: paidShare ?? this.paidShare,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  /// Balance after settling: positive = user owes, negative = owed to user
  double get balance => owedShare - paidShare;

  @override
  List<Object?> get props => [
        userId,
        userName,
        userAvatarUrl,
        owedShare,
        paidShare,
        percentage,
        shares,
        isSettled,
      ];
}
