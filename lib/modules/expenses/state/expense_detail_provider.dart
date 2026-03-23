import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';

final expenseDetailProvider = FutureProvider.family<ExpenseModel, String>((ref, expenseId) async {
  // Mock data - would be replaced with API call
  final currentUser = UserModel(
    id: 'user1',
    name: 'You',
    email: 'user@example.com',
    phone: '9876543210',
    avatarUrl: 'https://i.pravatar.cc/150?img=1',
    createdAt: DateTime.now(),
  );

  return ExpenseModel(
    id: expenseId,
    title: 'Flight Tickets',
    amount: 12000,
    currency: '₹',
    category: CategoryModel.travel,
    paidBy: currentUser,
    splits: [
      SplitModel(userId: 'user1', userName: 'You', userAvatarUrl: 'https://i.pravatar.cc/150?img=1', owedShare: 4000),
      SplitModel(userId: 'user2', userName: 'Raj', userAvatarUrl: 'https://i.pravatar.cc/150?img=2', owedShare: 4000),
      SplitModel(userId: 'user3', userName: 'Priya', userAvatarUrl: 'https://i.pravatar.cc/150?img=3', owedShare: 4000),
    ],
    date: DateTime.now(),
    notes: 'Goa trip flights',
    splitType: SplitType.equal,
    createdAt: DateTime.now(),
  );
});
