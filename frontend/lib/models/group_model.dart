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
  /// Optional base64-encoded cover photo. Populated by the backend's
  /// `coverImageBase64` field on findById/findAll responses; null when
  /// the group still uses the emoji-only fallback.
  final String? coverImageBase64;
  final List<UserModel> members;
  final double totalExpenses;
  /// Signed per-group net for the current user. Positive = others owe me net;
  /// negative = I owe net. Used for the group card.
  final double myBalance;
  /// Sum of positive pair-nets within this group — i.e. how much I am owed
  /// by people in this group, ignoring debts I have within the same group.
  /// Used by the "You're owed" detail screen so a group appears even when
  /// myBalance is negative.
  final double youAreOwedInGroup;
  /// Sum of |negative pair-nets| within this group — i.e. how much I owe
  /// to people in this group. Used by the "You owe" detail screen so a
  /// group appears even when myBalance is positive.
  final double youOweInGroup;
  final String currency;
  final DateTime createdAt;
  final GroupCategory category;
  final String? createdBy;

  const GroupModel({
    required this.id,
    required this.name,
    required this.coverEmoji,
    this.coverImageBase64,
    required this.members,
    this.totalExpenses = 0,
    this.myBalance = 0,
    this.youAreOwedInGroup = 0,
    this.youOweInGroup = 0,
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
    final rawCover = (json['coverImageBase64'] ?? json['cover_image_base64'])
        as String?;
    return GroupModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      coverEmoji: (json['coverEmoji'] as String?) ?? '👥',
      coverImageBase64:
          (rawCover != null && rawCover.isNotEmpty) ? rawCover : null,
      members: members,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0,
      myBalance: (json['myBalance'] as num?)?.toDouble() ?? 0,
      // Pair-level totals from the backend. Fall back to deriving from
      // myBalance when an older backend hasn't shipped these fields yet:
      // positive myBalance → all owed-to-me; negative → all owe.
      youAreOwedInGroup: (json['youAreOwedInGroup'] as num?)?.toDouble() ??
          (((json['myBalance'] as num?)?.toDouble() ?? 0) > 0
              ? ((json['myBalance'] as num).toDouble())
              : 0),
      youOweInGroup: (json['youOweInGroup'] as num?)?.toDouble() ??
          (((json['myBalance'] as num?)?.toDouble() ?? 0) < 0
              ? -((json['myBalance'] as num).toDouble())
              : 0),
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
    String? coverImageBase64,
    List<UserModel>? members,
    double? totalExpenses,
    double? myBalance,
    double? youAreOwedInGroup,
    double? youOweInGroup,
    String? currency,
    DateTime? createdAt,
    GroupCategory? category,
    String? createdBy,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      coverEmoji: coverEmoji ?? this.coverEmoji,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      members: members ?? this.members,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      myBalance: myBalance ?? this.myBalance,
      youAreOwedInGroup: youAreOwedInGroup ?? this.youAreOwedInGroup,
      youOweInGroup: youOweInGroup ?? this.youOweInGroup,
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
        coverImageBase64,
        members,
        totalExpenses,
        myBalance,
        youAreOwedInGroup,
        youOweInGroup,
        currency,
        createdAt,
        category,
        createdBy,
      ];
}
