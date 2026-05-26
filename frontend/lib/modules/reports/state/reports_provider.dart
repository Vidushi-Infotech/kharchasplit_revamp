import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/reports/reports_repository.dart';
import '../../auth/state/auth_provider.dart';

class ReportsData {
  final double totalSpending;
  final double totalOwed;
  final double totalYouOwe;

  /// Display name → amount (Food, Travel, …). Emojis live in [topCategories].
  final Map<String, double> categorySpending;

  /// 'Jan', 'Feb', … → amount. Bar chart consumes this directly.
  final Map<String, double> monthlySpending;

  final List<CategoryExpense> topCategories;

  const ReportsData({
    required this.totalSpending,
    required this.totalOwed,
    required this.totalYouOwe,
    required this.categorySpending,
    required this.monthlySpending,
    required this.topCategories,
  });

  static const empty = ReportsData(
    totalSpending: 0,
    totalOwed: 0,
    totalYouOwe: 0,
    categorySpending: {},
    monthlySpending: {},
    topCategories: [],
  );
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

String _periodWireValue(ReportsPeriod p) {
  switch (p) {
    case ReportsPeriod.month:
      return 'month';
    case ReportsPeriod.quarter:
      return 'quarter';
    case ReportsPeriod.year:
      return 'year';
  }
}

/// Category metadata used to humanise the backend's category id and pair it
/// with an emoji for the Reports UI. Falls back to "Other" / 📦.
class _CategoryMeta {
  const _CategoryMeta(this.label, this.emoji);
  final String label;
  final String emoji;
}

const Map<String, _CategoryMeta> _categoryMeta = {
  'food': _CategoryMeta('Food', '🍽️'),
  'travel': _CategoryMeta('Travel', '🚗'),
  'accommodation': _CategoryMeta('Hotel', '🏨'),
  'entertainment': _CategoryMeta('Entertainment', '🎬'),
  'shopping': _CategoryMeta('Shopping', '🛍️'),
  'utilities': _CategoryMeta('Utilities', '💡'),
  'medical': _CategoryMeta('Medical', '🏥'),
  'education': _CategoryMeta('Education', '🎓'),
  'gifts': _CategoryMeta('Gifts', '🎁'),
  'fuel': _CategoryMeta('Fuel', '⛽'),
  'work': _CategoryMeta('Work', '💼'),
  'other': _CategoryMeta('Other', '📦'),
};

_CategoryMeta _metaFor(String id) =>
    _categoryMeta[id.toLowerCase()] ?? const _CategoryMeta('Other', '📦');

/// Convert a 'YYYY-MM' bucket from the backend into a 3-letter month label
/// for the bar chart's X axis.
String _monthLabel(String yyyyMm) {
  const labels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final parts = yyyyMm.split('-');
  if (parts.length < 2) return yyyyMm;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return yyyyMm;
  return labels[m - 1];
}

/// Selected period (Month / Quarter / Year chip). The screen reads + writes
/// this; the reportsProvider re-runs whenever this changes.
final reportsPeriodProvider =
    StateProvider<ReportsPeriod>((ref) => ReportsPeriod.month);

/// Live, period-aware aggregation for the Reports screen. Re-fetches when
/// the user picks a different period chip and when auth state changes.
final reportsProvider = FutureProvider<ReportsData>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return ReportsData.empty;

  final period = ref.watch(reportsPeriodProvider);
  final summary = await ref
      .read(reportsRepositoryProvider)
      .getForUser(user.id, period: _periodWireValue(period));

  // Re-key categorySpending by display name (Food, Travel, …) so the pie
  // chart and bars match what the user sees in the expense form.
  final categoryDisplay = <String, double>{};
  summary.categorySpending.forEach((id, amount) {
    final meta = _metaFor(id);
    categoryDisplay[meta.label] = (categoryDisplay[meta.label] ?? 0) + amount;
  });

  final monthlyDisplay = <String, double>{};
  summary.monthlySpending.forEach((bucket, amount) {
    monthlyDisplay[_monthLabel(bucket)] = amount;
  });

  final topCategories = summary.topCategories.map((row) {
    final meta = _metaFor(row.categoryId);
    return CategoryExpense(
      category: meta.label,
      amount: row.amount,
      emoji: meta.emoji,
    );
  }).toList();

  return ReportsData(
    totalSpending: summary.totalSpending,
    totalOwed: summary.owedToYou,
    totalYouOwe: summary.youOwe,
    categorySpending: categoryDisplay,
    monthlySpending: monthlyDisplay,
    topCategories: topCategories,
  );
});
