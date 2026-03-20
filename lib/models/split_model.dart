import 'package:equatable/equatable.dart';

/// Split model representing how an expense is split among members
class SplitModel extends Equatable {
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final double owedShare;
  final double paidShare;
  final double percentage;
  final bool isSettled;

  const SplitModel({
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.owedShare,
    this.paidShare = 0,
    this.percentage = 0,
    this.isSettled = false,
  });

  SplitModel copyWith({
    String? userId,
    String? userName,
    String? userAvatarUrl,
    double? owedShare,
    double? paidShare,
    double? percentage,
    bool? isSettled,
  }) {
    return SplitModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      owedShare: owedShare ?? this.owedShare,
      paidShare: paidShare ?? this.paidShare,
      percentage: percentage ?? this.percentage,
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
        isSettled,
      ];
}
