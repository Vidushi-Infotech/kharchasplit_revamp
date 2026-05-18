import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/expenses/expenses_repository.dart';
import '../../../models/expense_model.dart';

/// Always fetches the full expense by id — the dashboard / list endpoints
/// strip heavy fields (`receipt_base64`) from their payloads to keep them
/// small, so we cannot reuse those cached models on the detail screen.
final expenseDetailProvider =
    FutureProvider.family<ExpenseModel, String>((ref, expenseId) async {
  return ref.read(expensesRepositoryProvider).getById(expenseId);
});
