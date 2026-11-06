import '../../../core/constants/app_strings.dart';
import '../../../models/activity_model.dart';

/// What tapping an Activity row does: open [route], and/or show [notice]
/// (e.g. the expense was deleted, so its group opens instead).
class ActivityTap {
  const ActivityTap({this.route, this.notice});

  final String? route;
  final String? notice;
}

/// Where an Activity row leads, Splitwise-style: an expense opens the
/// expense, a payment opens your payments with that person, anything else
/// its group. Deleted expenses fall back to the group; a deleted group, or
/// one you've left, only explains why nothing opens.
ActivityTap activityTap(ActivityModel a, {required String? myUserId}) {
  final groupId = a.group?.id ?? '';
  if (a.groupDeleted || a.type == ActivityType.groupDeleted) {
    return const ActivityTap(notice: AppStrings.activityGroupDeleted);
  }
  if (groupId.isNotEmpty && !a.inGroup) {
    return const ActivityTap(notice: AppStrings.activityNotInGroup);
  }
  final groupRoute = groupId.isEmpty ? null : '/home/groups/$groupId';
  final entityId = a.entityId ?? '';

  final isExpense =
      a.entityType == 'expense' ||
      a.type == ActivityType.expenseAdded ||
      a.type == ActivityType.expenseEdited ||
      a.type == ActivityType.expenseDeleted ||
      a.type == ActivityType.commentAdded;
  if (isExpense) {
    if (a.expenseDeleted || a.type == ActivityType.expenseDeleted) {
      return ActivityTap(
        route: groupRoute,
        notice: AppStrings.activityExpenseDeleted,
      );
    }
    if (entityId.isNotEmpty) return ActivityTap(route: '/expense/$entityId');
  }

  if (a.entityType == 'settlement' && groupRoute != null && myUserId != null) {
    final other = a.paymentFromId == myUserId
        ? a.paymentToId
        : (a.paymentToId == myUserId ? a.paymentFromId : null);
    if (other != null && other.isNotEmpty) {
      return ActivityTap(route: '$groupRoute/settlements-with/$other');
    }
  }
  return ActivityTap(route: groupRoute);
}
