import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';

class GroupsData {
  final List<GroupModel> groups;
  final bool isLoading;
  final String? error;

  const GroupsData({
    required this.groups,
    this.isLoading = false,
    this.error,
  });
}

final groupsProvider = StateProvider<GroupsData>((ref) {
  final user1 = UserModel(
    id: 'user1',
    name: 'You',
    email: 'user@example.com',
    phone: '9876543210',
    avatarUrl: 'https://i.pravatar.cc/150?img=1',
    createdAt: DateTime.now(),
  );

  final user2 = UserModel(
    id: 'user2',
    name: 'Raj',
    email: 'raj@example.com',
    phone: '9876543211',
    avatarUrl: 'https://i.pravatar.cc/150?img=2',
    createdAt: DateTime.now(),
  );

  final groups = [
    GroupModel(
      id: const Uuid().v4(),
      name: 'Goa Trip',
      coverEmoji: '🏝️',
      members: [user1, user2],
      totalExpenses: 15000,
      myBalance: 2500,
      currency: '₹',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      category: GroupCategory.trip,
    ),
    GroupModel(
      id: const Uuid().v4(),
      name: 'Home Rent',
      coverEmoji: '🏠',
      members: [user1, user2],
      totalExpenses: 45000,
      myBalance: -5000,
      currency: '₹',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      category: GroupCategory.home,
    ),
  ];

  return GroupsData(groups: groups);
});
