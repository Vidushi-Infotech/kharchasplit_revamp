import 'package:equatable/equatable.dart';
import '../core/utils/currency_formatter.dart';
import 'user_model.dart';

/// Group category enum
enum GroupCategory {
  trip,
  home,
  couple,
  work,
  other,
}

/// Group model representing a group of people splitting expenses
class GroupModel extends Equatable {
  final String id;
  final String name;
  final String coverEmoji;
  final List<UserModel> members;
  final double totalExpenses;
  final double myBalance;
  final String currency;
  final DateTime createdAt;
  final GroupCategory category;
  final String? createdBy;

  const GroupModel({
    required this.id,
    required this.name,
    required this.coverEmoji,
    required this.members,
    this.totalExpenses = 0,
    this.myBalance = 0,
    this.currency = '₹',
    required this.createdAt,
    this.category = GroupCategory.other,
    this.createdBy,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final members = rawMembers is List
        ? rawMembers
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .toList()
        : <UserModel>[];
    final created = json['created_at'] ?? json['createdAt'];
    return GroupModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      coverEmoji: (json['coverEmoji'] as String?) ?? '👥',
      members: members,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0,
      myBalance: (json['myBalance'] as num?)?.toDouble() ?? 0,
      currency: CurrencyFormatter.symbolFor(
          (json['currency'] as String?) ?? 'INR'),
      createdAt:
          created is String ? DateTime.parse(created) : DateTime.now(),
      category: GroupCategory.other,
      createdBy: (json['createdBy'] ?? json['created_by']) as String?,
    );
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? coverEmoji,
    List<UserModel>? members,
    double? totalExpenses,
    double? myBalance,
    String? currency,
    DateTime? createdAt,
    GroupCategory? category,
    String? createdBy,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      coverEmoji: coverEmoji ?? this.coverEmoji,
      members: members ?? this.members,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      myBalance: myBalance ?? this.myBalance,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Get member count
  int get memberCount => members.length;

  /// Get simplified category name
  String get categoryName {
    switch (category) {
      case GroupCategory.trip:
        return 'Trip';
      case GroupCategory.home:
        return 'Home';
      case GroupCategory.couple:
        return 'Couple';
      case GroupCategory.work:
        return 'Work';
      case GroupCategory.other:
        return 'Other';
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        coverEmoji,
        members,
        totalExpenses,
        myBalance,
        currency,
        createdAt,
        category,
        createdBy,
      ];
}
