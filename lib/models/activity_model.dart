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
