import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/expense_model.dart';
import '../../../models/category_model.dart';

class FriendDetail {
  final UserModel friend;
  final double balanceYouOwe; // negative = they owe you
  final List<ExpenseModel> sharedExpenses;

  const FriendDetail({
    required this.friend,
    required this.balanceYouOwe,
    required this.sharedExpenses,
  });
}

/// Friend detail provider
final friendDetailProvider = FutureProvider.family<FriendDetail, String>((ref, friendId) async {
  // Simulate network delay
  await Future.delayed(const Duration(milliseconds: 500));

  final now = DateTime.now();

  // Mock data
  final mockFriend = UserModel(
    id: friendId,
    name: 'Priya Sharma',
    email: 'priya@example.com',
    phone: '+919876543211',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=priya',
    createdAt: now,
  );

  final mockSharedExpenses = [
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
      paidBy: mockFriend,
      splits: [],
      groupId: 'grp_001',
      date: now,
      createdAt: now,
      notes: 'Goa Trip',
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
      paidBy: UserModel(
        id: 'user_001',
        name: 'You',
        email: 'you@example.com',
        phone: '+919876543210',
        createdAt: now,
      ),
      splits: [],
      groupId: 'grp_001',
      date: now,
      createdAt: now,
      notes: 'Dinner at Taj',
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
      paidBy: mockFriend,
      splits: [],
      groupId: 'grp_001',
      date: now,
      createdAt: now,
      notes: 'Airport transport',
    ),
  ];

  // Calculate balance: if positive, you owe them; if negative, they owe you
  double balance = 0;
  for (final expense in mockSharedExpenses) {
    if (expense.paidBy.id == friendId) {
      // They paid, you owe them your share
      balance += expense.amount / 2;
    } else {
      // You paid, they owe you their share
      balance -= expense.amount / 2;
    }
  }

  return FriendDetail(
    friend: mockFriend,
    balanceYouOwe: balance,
    sharedExpenses: mockSharedExpenses,
  );
});
