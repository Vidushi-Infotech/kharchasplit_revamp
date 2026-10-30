import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/personal_expenses/personal_expenses_repository.dart';
import '../../../models/personal_summary_model.dart';
import 'personal_expenses_provider.dart';

/// The month the Insights tab shows (its first day); starts at this month.
final insightsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Insights for [insightsMonthProvider]. Re-fetched when an entry is added
/// or deleted (it follows the Personal list).
final personalSummaryProvider = FutureProvider.autoDispose<PersonalSummary>((
  ref,
) {
  final month = ref.watch(insightsMonthProvider);
  ref.watch(personalExpensesProvider.select((s) => s.value));
  return ref.read(personalExpensesRepositoryProvider).summary(month);
});
