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
  settlementConfirmed,
  settlementDeleted,
  groupCreated,
  groupUpdated,
  groupArchived,
  groupDeleted,
  memberAdded,
  memberRemoved,
  memberRoleUpdated,
  commentAdded,
  other,
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

  /// Who did it (`userId` on the feed row). The personal feed only lists
  /// your own actions today, but the sentence builder doesn't assume that.
  final String? actorId;

  /// What the row points at: `expense`, `settlement`, `group` or `member`,
  /// and that thing's id (an expense id for expense rows).
  final String? entityType;
  final String? entityId;

  /// Server `metadata`: expenseDescription, amount, currency, fromName,
  /// toName, memberName, newRole, changes… — whatever the event logged.
  final Map<String, dynamic> metadata;

  /// Expense rows only: the expense's category id and the viewer's net on
  /// it (paid − share; positive = you get back). Null when the server
  /// didn't send it or you're not involved.
  final String? category;
  final double? yourNet;

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
    this.actorId,
    this.entityType,
    this.entityId,
    this.metadata = const {},
    this.category,
    this.yourNet,
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
      description:
          ((json['description'] as String?)?.trim().isNotEmpty ?? false)
          ? json['description'] as String
          : (json['title'] as String? ?? ''),
      timestamp: created is String ? DateTime.parse(created) : DateTime.now(),
      isRead: (json['isRead'] as bool?) ?? false,
      actorId: (json['userId'] ?? json['user_id']) as String?,
      entityType: (json['entityType'] ?? json['entity_type']) as String?,
      entityId: (json['entityId'] ?? json['entity_id']) as String?,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      category: json['category'] as String?,
      yourNet: (json['yourNet'] as num?)?.toDouble(),
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
      case 'settlement_created':
        return ActivityType.settled;
      case 'settlement_confirmed':
        return ActivityType.settlementConfirmed;
      case 'settlement_deleted':
        return ActivityType.settlementDeleted;
      case 'group_created':
        return ActivityType.groupCreated;
      case 'group_updated':
        return ActivityType.groupUpdated;
      case 'group_archived':
        return ActivityType.groupArchived;
      case 'group_deleted':
        return ActivityType.groupDeleted;
      case 'member_added':
        return ActivityType.memberAdded;
      case 'member_removed':
        return ActivityType.memberRemoved;
      case 'member_role_updated':
        return ActivityType.memberRoleUpdated;
      case 'comment_added':
        return ActivityType.commentAdded;
      default:
        // Unknown events used to read as "Expense added"; show the
        // server's own description instead.
        return ActivityType.other;
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
    String? actorId,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    String? category,
    double? yourNet,
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
      actorId: actorId ?? this.actorId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      metadata: metadata ?? this.metadata,
      category: category ?? this.category,
      yourNet: yourNet ?? this.yourNet,
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
      case ActivityType.settlementConfirmed:
        return 'Payment Confirmed';
      case ActivityType.settlementDeleted:
        return 'Payment Deleted';
      case ActivityType.groupCreated:
        return 'Group Created';
      case ActivityType.groupUpdated:
        return 'Group Updated';
      case ActivityType.groupArchived:
        return 'Group Archived';
      case ActivityType.groupDeleted:
        return 'Group Deleted';
      case ActivityType.memberAdded:
        return 'Member Added';
      case ActivityType.memberRemoved:
        return 'Member Removed';
      case ActivityType.memberRoleUpdated:
        return 'Member Role Updated';
      case ActivityType.commentAdded:
        return 'Comment Added';
      case ActivityType.other:
        return 'Activity';
    }
  }

  /// Get activity icon
  String get icon {
    switch (type) {
      case ActivityType.expenseAdded:
      case ActivityType.expenseEdited:
        return '💸';
      case ActivityType.expenseDeleted:
      case ActivityType.settlementDeleted:
      case ActivityType.groupDeleted:
        return '🗑️';
      case ActivityType.settled:
      case ActivityType.settlementConfirmed:
        return '✅';
      case ActivityType.groupCreated:
      case ActivityType.groupUpdated:
      case ActivityType.groupArchived:
        return '👥';
      case ActivityType.memberAdded:
      case ActivityType.memberRemoved:
      case ActivityType.memberRoleUpdated:
        return '👤';
      case ActivityType.commentAdded:
        return '💬';
      case ActivityType.other:
        return '•';
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
    actorId,
    entityType,
    entityId,
    metadata,
    category,
    yourNet,
  ];
}
