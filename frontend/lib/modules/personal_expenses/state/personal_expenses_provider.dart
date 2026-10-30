import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/personal_expenses/personal_expenses_repository.dart';
import '../../../models/personal_expense_model.dart';
import '../../auth/state/auth_provider.dart';
import 'wallet_provider.dart';

final personalExpensesProvider =
    AsyncNotifierProvider<PersonalExpensesNotifier, List<PersonalExpenseModel>>(
      PersonalExpensesNotifier.new,
    );

class PersonalExpensesNotifier
    extends AsyncNotifier<List<PersonalExpenseModel>> {
  @override
  Future<List<PersonalExpenseModel>> build() async {
    final user = ref.watch(authProvider).user;
    if (user == null) return const [];
    return ref.read(personalExpensesRepositoryProvider).listForUser(user.id);
  }

  /// Re-fetches while keeping the current data on screen. `invalidateSelf`
  /// re-runs [build] with refresh semantics (previous value retained,
  /// `isRefreshing == true`), so `.when()` keeps rendering the data branch
  /// instead of dropping to a skeleton. It also disposes and re-registers the
  /// listeners set up in [build], which calling `build()` by hand never did.
  /// A failed fetch lands in [state] rather than being thrown, matching the
  /// old `AsyncValue.guard` behaviour.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Already reflected in state.
    }
  }

  Future<PersonalExpenseModel> addExpense({
    required String description,
    required double amount,
    String currency = 'INR',
    String? category,
    String? notes,
    DateTime? expenseDate,
    bool isIncome = false,
    String? accountId,
  }) async {
    final created = await ref
        .read(personalExpensesRepositoryProvider)
        .create(
          isIncome: isIncome,
          accountId: accountId,
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
    // Look up the entry before deleting so we know how much to put back.
    final items = state.value ?? const <PersonalExpenseModel>[];
    final target = items.firstWhereOrNull((e) => e.id == id);
    await ref.read(personalExpensesRepositoryProvider).delete(id);
    state = state.whenData((items) => items.where((e) => e.id != id).toList());
    if (target != null) {
      await ref
          .read(walletProvider.notifier)
          .refundExpense(expenseId: id, amount: -target.signedAmount);
    }
  }
}

/// Total spent across all visible personal expenses (currency-agnostic sum).
/// Income isn't spending, so it's left out.
final personalExpensesTotalProvider = Provider<double>((ref) {
  final items =
      ref.watch(personalExpensesProvider).value ??
      const <PersonalExpenseModel>[];
  return items
      .where((e) => !e.isIncome)
      .fold<double>(0, (sum, e) => sum + e.amount);
});

/// Money in and out over one calendar month.
class CashFlow {
  const CashFlow({required this.income, required this.spent});

  final double income;
  final double spent;

  double get net => income - spent;

  static CashFlow of(Iterable<PersonalExpenseModel> items, DateTime month) {
    var income = 0.0;
    var spent = 0.0;
    for (final e in items) {
      final d = e.expenseDate;
      if (d.year != month.year || d.month != month.month) continue;
      if (e.isIncome) {
        income += e.amount;
      } else {
        spent += e.amount;
      }
    }
    return CashFlow(income: income, spent: spent);
  }
}

/// This month's cash flow (In · Out · Net) for the Personal home.
final personalCashFlowProvider = Provider<CashFlow>((ref) {
  final items =
      ref.watch(personalExpensesProvider).value ??
      const <PersonalExpenseModel>[];
  return CashFlow.of(items, DateTime.now());
});
