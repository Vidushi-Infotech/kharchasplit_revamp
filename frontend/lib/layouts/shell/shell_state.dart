import 'package:flutter_riverpod/legacy.dart';

/// Provider for selected navigation index
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

/// Provider for unread activity count (badge)
final unreadActivityCountProvider = StateProvider<int>((ref) => 3);

/// Tab order shared by the mobile bottom bar and the tablet rail
/// (Splitwise-style): Groups · Friends · ➕ · Activity · Account.
abstract final class ShellTab {
  static const groups = 0;
  static const friends = 1;
  static const create = 2;
  static const activity = 3;
  static const account = 4;

  /// Where each tab lands. [create] has no route of its own — the shells
  /// open the add-expense flow instead.
  static const locations = <int, String>{
    groups: '/home/groups',
    friends: '/home/friends',
    activity: '/home/activity',
    account: '/home/profile',
  };

  /// Map a route location to the tab it belongs to. Returns null when the
  /// location isn't owned by a tab (e.g. deep links like
  /// /home/groups/:groupId pushed over the shell) — callers then keep the
  /// last-tapped index.
  static int? fromLocation(String location) {
    // Old Home links redirect to Groups; light Groups up while they do.
    if (location.startsWith('/home/dashboard')) return groups;
    if (location.startsWith('/home/groups')) return groups;
    if (location.startsWith('/home/friends')) return friends;
    if (location.startsWith('/home/create-group') ||
        location.startsWith('/add-expense')) {
      return create;
    }
    if (location.startsWith('/home/activity') ||
        location.startsWith('/home/notifications')) {
      return activity;
    }
    if (location.startsWith('/home/profile')) return account;
    return null;
  }
}
