import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/keep_alive_for.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/expense_model.dart';

/// Always fetches the full expense by id — the dashboard / list endpoints
/// strip heavy fields (`receipt_base64`) from their payloads to keep them
/// small, so we cannot reuse those cached models on the detail screen.
///
/// Short cache: the payload carries the full receipt image, so we don't want
/// dozens of these lingering in memory.
final expenseDetailProvider = FutureProvider.autoDispose
    .family<ExpenseModel, String>((ref, expenseId) async {
  keepAliveFor(ref, const Duration(minutes: 2));
  return ref.read(expensesRepositoryProvider).getById(expenseId);
});
