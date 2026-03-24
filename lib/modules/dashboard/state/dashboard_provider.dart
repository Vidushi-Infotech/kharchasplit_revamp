import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';

/// Dashboard data state
class DashboardData {
  final double totalBalance;
  final double youAreOwed;
  final double youOwe;
  final List<GroupModel> recentGroups;
  final List<ExpenseModel> recentExpenses;

  const DashboardData({
    required this.totalBalance,
    required this.youAreOwed,
    required this.youOwe,
    required this.recentGroups,
    required this.recentExpenses,
  });
}

/// Mock dashboard provider with sample data
final dashboardProvider = StateProvider<DashboardData>((ref) {
  final currentUser = UserModel(
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
      members: [currentUser, user2],
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
      members: [currentUser, user2],
      totalExpenses: 45000,
      myBalance: -5000,
      currency: '₹',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      category: GroupCategory.home,
    ),
  ];

  final expenses = [
    ExpenseModel(
      id: const Uuid().v4(),
      title: 'Flight Tickets',
      amount: 12000,
      currency: '₹',
      category: CategoryModel.travel,
      paidBy: currentUser,
      splits: [
        SplitModel(userId: 'user1', userName: 'You', owedShare: 4000),
      ],
      date: DateTime.now().subtract(const Duration(hours: 5)),
      splitType: SplitType.equal,
      createdAt: DateTime.now(),
    ),
  ];

  return DashboardData(
    totalBalance: 2500,
    youAreOwed: 7500,
    youOwe: 5000,
    recentGroups: groups,
    recentExpenses: expenses,
  );
});
