import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/personal_bills/personal_bills_repository.dart';
import '../../../models/personal_bill_model.dart';
import '../../auth/state/auth_provider.dart';
import 'personal_expenses_provider.dart';

/// The user's bills, soonest due first.
final personalBillsProvider =
    AsyncNotifierProvider<PersonalBillsNotifier, List<PersonalBill>>(
      PersonalBillsNotifier.new,
    );

class PersonalBillsNotifier extends AsyncNotifier<List<PersonalBill>> {
  PersonalBillsRepository get _repo =>
      ref.read(personalBillsRepositoryProvider);

  @override
  Future<List<PersonalBill>> build() {
    ref.watch(myIdProvider);
    return _repo.list();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Already reflected in state.
    }
  }

  Future<void> save({
    String? id,
    required String name,
    required double amount,
    required String category,
    BillFrequency? frequency,
    DateTime? dueDate,
    required int remindDays,
    String? accountId,
  }) async {
    await _repo.save(
      id: id,
      name: name,
      amount: amount,
      category: category,
      frequency: frequency,
      dueDate: dueDate,
      remindDays: remindDays,
      accountId: accountId,
    );
    await refresh();
  }

  Future<void> archive(String id) async {
    await _repo.archive(id);
    await refresh();
  }

  /// Pays it: the new expense shows on Home, and the account balance, the
  /// budgets and the insights follow the expense list.
  Future<void> pay(String id, {double? amount, String? accountId}) async {
    await _repo.pay(id, amount: amount, accountId: accountId);
    await Future.wait([
      refresh(),
      ref.read(personalExpensesProvider.notifier).refresh(),
    ]);
  }

  Future<void> skip(String id) async {
    await _repo.skip(id);
    await refresh();
  }
}
