import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/personal_budgets/personal_budgets_repository.dart';
import '../../../models/personal_budget_model.dart';
import '../../auth/state/auth_provider.dart';
import 'personal_expenses_provider.dart';

/// This month's budgets with their spending. Re-fetched when a personal
/// entry is added or deleted (it follows the Personal list), which is how
/// the add screen sees whether a budget alert is due.
final personalBudgetsProvider =
    AsyncNotifierProvider<PersonalBudgetsNotifier, BudgetsOverview>(
      PersonalBudgetsNotifier.new,
    );

class PersonalBudgetsNotifier extends AsyncNotifier<BudgetsOverview> {
  PersonalBudgetsRepository get _repo =>
      ref.read(personalBudgetsRepositoryProvider);

  @override
  Future<BudgetsOverview> build() {
    ref.watch(myIdProvider);
    ref.watch(personalExpensesProvider.select((s) => s.value));
    return _repo.overview(DateTime.now());
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Already reflected in state.
    }
  }

  Future<void> setBudget(String category, double amount) async {
    await _repo.set(category, amount);
    await refresh();
  }

  Future<void> removeBudget(String category) async {
    await _repo.remove(category);
    await refresh();
  }
}
