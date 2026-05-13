import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/expenses/expenses_repository.dart';
import '../../../models/expense_model.dart';
import '../../dashboard/state/dashboard_provider.dart';

final expenseDetailProvider =
    FutureProvider.family<ExpenseModel, String>((ref, expenseId) async {
  // Cheap path: serve from the dashboard's recent-expenses cache when present.
  final recent =
      ref.watch(dashboardProvider).value?.recentExpenses ?? const <ExpenseModel>[];
  final cached = recent
      .where((e) => e.id == expenseId)
      .cast<ExpenseModel?>()
      .firstWhere((e) => true, orElse: () => null);
  if (cached != null) return cached;

  return ref.read(expensesRepositoryProvider).getById(expenseId);
});
