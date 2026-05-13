import 'package:equatable/equatable.dart';
import 'user_model.dart';
import 'group_model.dart';
import 'expense_model.dart';

/// Activity type enum
enum ActivityType {
  expenseAdded,
  expenseEdited,
  expenseDeleted,
  settled,
  groupCreated,
  memberAdded,
  memberRemoved,
  commentAdded,
}

/// Activity model representing an event in the app
class ActivityModel extends Equatable {
  final String id;
  final ActivityType type;
  final UserModel? actorUser;
  final UserModel? targetUser;
  final GroupModel? group;
  final ExpenseModel? expense;
  final String description;
  final DateTime timestamp;
  final bool isRead;

  const ActivityModel({
    required this.id,
    required this.type,
    this.actorUser,
    this.targetUser,
    this.group,
    this.expense,
    required this.description,
    required this.timestamp,
    this.isRead = false,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['activityType'] as String?);
    final actorName = (json['actorName'] as String?)?.trim();
    final actorUser = (actorName != null && actorName.isNotEmpty)
        ? UserModel(
            id: '',
            name: actorName,
            email: '',
            phone: '',
            createdAt: DateTime.now(),
          )
        : null;
    final groupId = json['groupId'] as String?;
    final groupName = (json['groupName'] as String?) ?? '';
    final group = (groupId != null && groupId.isNotEmpty)
        ? GroupModel(
            id: groupId,
            name: groupName,
            coverEmoji: '👥',
            members: const [],
            createdAt: DateTime.now(),
          )
        : null;
    final created = json['createdAt'] ?? json['created_at'];
    return ActivityModel(
      id: json['id'] as String,
      type: type,
      actorUser: actorUser,
      group: group,
      description: ((json['description'] as String?)?.trim().isNotEmpty ?? false)
          ? json['description'] as String
          : (json['title'] as String? ?? ''),
      timestamp: created is String ? DateTime.parse(created) : DateTime.now(),
      isRead: (json['isRead'] as bool?) ?? false,
    );
  }

  static ActivityType _parseType(String? raw) {
    switch (raw) {
      case 'expense_added':
        return ActivityType.expenseAdded;
      case 'expense_edited':
      case 'expense_updated':
        return ActivityType.expenseEdited;
      case 'expense_deleted':
        return ActivityType.expenseDeleted;
      case 'settled':
      case 'settlement_added':
        return ActivityType.settled;
      case 'group_created':
        return ActivityType.groupCreated;
      case 'group_updated':
        return ActivityType.groupCreated;
      case 'member_added':
        return ActivityType.memberAdded;
      case 'member_removed':
        return ActivityType.memberRemoved;
      case 'comment_added':
        return ActivityType.commentAdded;
      default:
        return ActivityType.expenseAdded;
    }
  }

  ActivityModel copyWith({
    String? id,
    ActivityType? type,
    UserModel? actorUser,
    UserModel? targetUser,
    GroupModel? group,
    ExpenseModel? expense,
    String? description,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      type: type ?? this.type,
      actorUser: actorUser ?? this.actorUser,
      targetUser: targetUser ?? this.targetUser,
      group: group ?? this.group,
      expense: expense ?? this.expense,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Get human-readable activity type name
  String get typeName {
    switch (type) {
      case ActivityType.expenseAdded:
        return 'Expense Added';
      case ActivityType.expenseEdited:
        return 'Expense Edited';
      case ActivityType.expenseDeleted:
        return 'Expense Deleted';
      case ActivityType.settled:
        return 'Settled';
      case ActivityType.groupCreated:
        return 'Group Created';
      case ActivityType.memberAdded:
        return 'Member Added';
      case ActivityType.memberRemoved:
        return 'Member Removed';
      case ActivityType.commentAdded:
        return 'Comment Added';
    }
  }

  /// Get activity icon
  String get icon {
    switch (type) {
      case ActivityType.expenseAdded:
      case ActivityType.expenseEdited:
        return '💸';
      case ActivityType.expenseDeleted:
        return '🗑️';
      case ActivityType.settled:
        return '✅';
      case ActivityType.groupCreated:
        return '👥';
      case ActivityType.memberAdded:
      case ActivityType.memberRemoved:
        return '👤';
      case ActivityType.commentAdded:
        return '💬';
    }
  }

  @override
  List<Object?> get props => [
        id,
        type,
        actorUser,
        targetUser,
        group,
        expense,
        description,
        timestamp,
        isRead,
      ];
}
