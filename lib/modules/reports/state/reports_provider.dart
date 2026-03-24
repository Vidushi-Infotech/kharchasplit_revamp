import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class ReportsData {
  final double totalSpending;
  final double totalOwed;
  final double totalYouOwe;
  final Map<String, double> categorySpending; // category -> amount
  final Map<String, double> monthlySpending; // month -> amount
  final List<CategoryExpense> topCategories;

  const ReportsData({
    required this.totalSpending,
    required this.totalOwed,
    required this.totalYouOwe,
    required this.categorySpending,
    required this.monthlySpending,
    required this.topCategories,
  });
}

class CategoryExpense {
  final String category;
  final double amount;
  final String emoji;

  const CategoryExpense({
    required this.category,
    required this.amount,
    required this.emoji,
  });
}

enum ReportsPeriod { month, quarter, year }

/// Reports provider
final reportsPeriodProvider = StateProvider<ReportsPeriod>((ref) => ReportsPeriod.month);

final reportsProvider = FutureProvider<ReportsData>((ref) async {
  // Simulate network delay
  await Future.delayed(const Duration(milliseconds: 500));

  // Mock data
  return const ReportsData(
    totalSpending: 45500.00,
    totalOwed: 28200.00,
    totalYouOwe: 17300.00,
    categorySpending: {
      'Food': 12500.00,
      'Travel': 15800.00,
      'Hotel': 8200.00,
      'Entertainment': 5300.00,
      'Shopping': 3700.00,
    },
    monthlySpending: {
      'Jan': 8500.00,
      'Feb': 12300.00,
      'Mar': 24700.00,
    },
    topCategories: [
      CategoryExpense(category: 'Travel', amount: 15800.00, emoji: '🚗'),
      CategoryExpense(category: 'Food', amount: 12500.00, emoji: '🍽️'),
      CategoryExpense(category: 'Hotel', amount: 8200.00, emoji: '🏨'),
      CategoryExpense(category: 'Entertainment', amount: 5300.00, emoji: '🎬'),
      CategoryExpense(category: 'Shopping', amount: 3700.00, emoji: '🛍️'),
    ],
  );
});
