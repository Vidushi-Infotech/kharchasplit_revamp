import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/personal_expenses/personal_expenses_repository.dart';
import '../../../models/personal_expense_model.dart';
import '../../auth/state/auth_provider.dart';
import 'wallet_provider.dart';

final personalExpensesProvider = AsyncNotifierProvider<
    PersonalExpensesNotifier, List<PersonalExpenseModel>>(
  PersonalExpensesNotifier.new,
);

class PersonalExpensesNotifier
    extends AsyncNotifier<List<PersonalExpenseModel>> {
  @override
  Future<List<PersonalExpenseModel>> build() async {
    final user = ref.watch(authProvider).user;
    if (user == null) return const [];
    return ref
        .read(personalExpensesRepositoryProvider)
        .listForUser(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<PersonalExpenseModel> addExpense({
    required String description,
    required double amount,
    String currency = 'INR',
    String? category,
    String? notes,
    DateTime? expenseDate,
  }) async {
    final created = await ref
        .read(personalExpensesRepositoryProvider)
        .create(
          description: description,
          amount: amount,
          currency: currency,
          category: category,
          notes: notes,
          expenseDate: expenseDate,
        );
    await refresh();
    return created;
  }

  Future<void> deleteExpense(String id) async {
    // Look up amount before deleting so we know how much to refund.
    final items = state.value ?? const <PersonalExpenseModel>[];
    final target = items.firstWhereOrNull((e) => e.id == id);
    await ref.read(personalExpensesRepositoryProvider).delete(id);
    state = state.whenData(
        (items) => items.where((e) => e.id != id).toList());
    if (target != null) {
      await ref
          .read(walletProvider.notifier)
          .refundExpense(expenseId: id, amount: target.amount);
    }
  }
}

/// Total spent across all visible personal expenses (currency-agnostic sum).
final personalExpensesTotalProvider = Provider<double>((ref) {
  final items =
      ref.watch(personalExpensesProvider).value ?? const <PersonalExpenseModel>[];
  return items.fold<double>(0, (sum, e) => sum + e.amount);
});
