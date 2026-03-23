import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../../models/expense_model.dart';
import '../../../models/category_model.dart';
import '../../../models/split_model.dart';

class GroupDetail {
  final GroupModel group;
  final List<UserModel> members;
  final List<ExpenseModel> expenses;
  final Map<String, double> memberBalances; // userId -> balance (positive = they owe money, negative = they are owed)
  final double totalExpense;

  const GroupDetail({
    required this.group,
    required this.members,
    required this.expenses,
    required this.memberBalances,
    required this.totalExpense,
  });
}

/// Group detail provider
final groupDetailProvider = FutureProvider.family<GroupDetail, String>((ref, groupId) async {
  // Simulate network delay
  await Future.delayed(const Duration(milliseconds: 500));

  // Mock data
  final now = DateTime.now();
  final mockMembers = [
    UserModel(
      id: 'user_001',
      name: 'Rahul Verma',
      email: 'rahul@example.com',
      phone: '+919876543210',
      avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=rahul',
      createdAt: now,
    ),
    UserModel(
      id: 'user_002',
      name: 'Priya Sharma',
      email: 'priya@example.com',
      phone: '+919876543211',
      avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=priya',
      createdAt: now,
    ),
    UserModel(
      id: 'user_003',
      name: 'Anjali Patel',
      email: 'anjali@example.com',
      phone: '+919876543212',
      avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=anjali',
      createdAt: now,
    ),
  ];

  final mockExpenses = [
    ExpenseModel(
      id: 'exp_001',
      title: 'Hotel booking',
      amount: 2500.00,
      category: const CategoryModel(
        id: 'cat_004',
        name: 'Hotel',
        colorHex: '#FF6B6B',
        icon: Icons.hotel_rounded,
      ),
      paidBy: mockMembers[1],
      splits: [],
      groupId: groupId,
      date: now,
      createdAt: now,
      notes: 'Ocean View Resort',
    ),
    ExpenseModel(
      id: 'exp_002',
      title: 'Dinner',
      amount: 1500.00,
      category: const CategoryModel(
        id: 'cat_001',
        name: 'Food',
        colorHex: '#FFD93D',
        icon: Icons.restaurant_rounded,
      ),
      paidBy: mockMembers[0],
      splits: [],
      groupId: groupId,
      date: now,
      createdAt: now,
      notes: 'Restaurant',
    ),
    ExpenseModel(
      id: 'exp_003',
      title: 'Cab',
      amount: 800.00,
      category: const CategoryModel(
        id: 'cat_002',
        name: 'Travel',
        colorHex: '#A8DADC',
        icon: Icons.directions_car_rounded,
      ),
      paidBy: mockMembers[2],
      splits: [],
      groupId: groupId,
      date: now,
      createdAt: now,
      notes: 'Airport transport',
    ),
  ];

  // Calculate member balances
  final memberBalances = <String, double>{};
  for (final member in mockMembers) {
    memberBalances[member.id] = 0;
  }

  double totalExpense = 0;
  for (final expense in mockExpenses) {
    totalExpense += expense.amount;
    final perPersonShare = expense.amount / mockMembers.length;

    // Add to payer
    memberBalances[expense.paidBy.id] = (memberBalances[expense.paidBy.id] ?? 0) - perPersonShare * (mockMembers.length - 1);

    // Add to others
    for (final member in mockMembers) {
      if (member.id != expense.paidBy.id) {
        memberBalances[member.id] = (memberBalances[member.id] ?? 0) + perPersonShare;
      }
    }
  }

  return GroupDetail(
    group: GroupModel(
      id: groupId,
      name: 'Goa Trip',
      coverEmoji: '✈️',
      category: GroupCategory.trip,
      members: mockMembers,
      createdAt: now.subtract(const Duration(days: 10)),
    ),
    members: mockMembers,
    expenses: mockExpenses,
    memberBalances: memberBalances,
    totalExpense: totalExpense,
  );
});

/// Group tab provider
enum GroupTab { balances, expenses }

final groupTabProvider = StateProvider<GroupTab>((ref) => GroupTab.expenses);
