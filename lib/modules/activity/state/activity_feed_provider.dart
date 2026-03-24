import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../models/activity_model.dart';
import '../../../models/user_model.dart';
import '../../../models/group_model.dart';

/// Activity feed provider with mock data
final activityFeedProvider = FutureProvider<List<ActivityModel>>((ref) async {
  // Simulate network delay
  await Future.delayed(const Duration(milliseconds: 500));

  final now = DateTime.now();

  // Mock users
  final priya = UserModel(
    id: 'user_002',
    name: 'Priya Sharma',
    email: 'priya@example.com',
    phone: '+919876543211',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=priya',
    createdAt: now,
  );

  final rahul = UserModel(
    id: 'user_001',
    name: 'Rahul Verma',
    email: 'rahul@example.com',
    phone: '+919876543210',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=rahul',
    createdAt: now,
  );

  final anjali = UserModel(
    id: 'user_003',
    name: 'Anjali Patel',
    email: 'anjali@example.com',
    phone: '+919876543212',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=anjali',
    createdAt: now,
  );

  final neha = UserModel(
    id: 'user_004',
    name: 'Neha Singh',
    email: 'neha@example.com',
    phone: '+919876543213',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=neha',
    createdAt: now,
  );

  // Mock groups
  final goaTrip = GroupModel(
    id: 'grp_001',
    name: 'Goa Trip',
    coverEmoji: '✈️',
    category: GroupCategory.trip,
    members: [rahul, priya, anjali],
    createdAt: now.subtract(const Duration(days: 10)),
  );

  final homeRent = GroupModel(
    id: 'grp_002',
    name: 'Home Rent',
    coverEmoji: '🏠',
    category: GroupCategory.home,
    members: [rahul, anjali],
    createdAt: now.subtract(const Duration(days: 30)),
  );

  // Mock data - activity feed
  final mockActivities = [
    ActivityModel(
      id: 'act_001',
      type: ActivityType.expenseAdded,
      actorUser: priya,
      group: goaTrip,
      description: 'Priya added expense "Hotel booking" ₹2,500',
      timestamp: now.subtract(const Duration(hours: 2)),
      isRead: true,
    ),
    ActivityModel(
      id: 'act_002',
      type: ActivityType.settled,
      actorUser: rahul,
      targetUser: anjali,
      group: goaTrip,
      description: 'Rahul settled ₹3,200 with Anjali',
      timestamp: now.subtract(const Duration(hours: 5)),
      isRead: true,
    ),
    ActivityModel(
      id: 'act_003',
      type: ActivityType.expenseAdded,
      actorUser: anjali,
      group: homeRent,
      description: 'Anjali added expense "March rent" ₹15,000',
      timestamp: now.subtract(const Duration(days: 1)),
      isRead: true,
    ),
    ActivityModel(
      id: 'act_004',
      type: ActivityType.memberAdded,
      actorUser: rahul,
      targetUser: neha,
      group: goaTrip,
      description: 'Rahul added Neha to "Goa Trip"',
      timestamp: now.subtract(const Duration(days: 1, hours: 3)),
      isRead: false,
    ),
    ActivityModel(
      id: 'act_005',
      type: ActivityType.expenseEdited,
      actorUser: priya,
      group: goaTrip,
      description: 'Priya edited expense "Dinner" amount changed to ₹1,800',
      timestamp: now.subtract(const Duration(days: 2)),
      isRead: true,
    ),
    ActivityModel(
      id: 'act_006',
      type: ActivityType.groupCreated,
      actorUser: rahul,
      group: goaTrip,
      description: 'Rahul created group "Goa Trip"',
      timestamp: now.subtract(const Duration(days: 3)),
      isRead: true,
    ),
  ];

  return mockActivities;
});

/// Activity filter provider
enum ActivityFilter { all, expenses, settlements, groups }

final activityFilterProvider = StateProvider<ActivityFilter>((ref) => ActivityFilter.all);

/// Filtered activity feed
final filteredActivityFeedProvider = Provider<AsyncValue<List<ActivityModel>>>((ref) {
  final feedAsync = ref.watch(activityFeedProvider);
  final filter = ref.watch(activityFilterProvider);

  return feedAsync.whenData((activities) {
    switch (filter) {
      case ActivityFilter.all:
        return activities;
      case ActivityFilter.expenses:
        return activities
            .where((a) => a.type == ActivityType.expenseAdded || a.type == ActivityType.expenseEdited || a.type == ActivityType.expenseDeleted)
            .toList();
      case ActivityFilter.settlements:
        return activities.where((a) => a.type == ActivityType.settled).toList();
      case ActivityFilter.groups:
        return activities.where((a) => a.type == ActivityType.groupCreated || a.type == ActivityType.memberAdded || a.type == ActivityType.memberRemoved).toList();
    }
  });
});
