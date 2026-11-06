import 'package:collection/collection.dart';

import '../../../core/constants/app_strings.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';

/// How a group is named on screen. A normal group shows its own name; the
/// hidden two-person "direct" group (non-group expenses with one friend)
/// is named after the friend instead of its server name.
extension GroupDisplay on GroupModel {
  /// The other member of a direct group, or null for a normal group (or a
  /// direct group whose members haven't loaded).
  UserModel? directFriend(String? myId) =>
      isDirect ? members.firstWhereOrNull((m) => m.id != myId) : null;

  /// "You and Priya" for a direct group, else the group's name.
  String displayTitle(String? myId) {
    if (!isDirect) return name;
    final friend = directFriend(myId);
    return friend == null || friend.name.isEmpty
        ? AppStrings.nonGroupExpenses
        : AppStrings.youAndName(friend.name);
  }

  /// Context line on an expense form: "With Priya" for a direct group,
  /// "In Goa trip" otherwise.
  String expenseContextLabel(String? myId) {
    if (!isDirect) return AppStrings.inGroupName(name);
    final friend = directFriend(myId);
    return friend == null || friend.name.isEmpty
        ? AppStrings.nonGroupExpenses
        : AppStrings.withName(friend.name);
  }
}
