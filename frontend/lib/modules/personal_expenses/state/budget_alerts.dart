import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/push_service.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category_model.dart';
import '../../../models/personal_budget_model.dart';
import 'personal_budgets_provider.dart';

/// Budget alerts for a new personal expense: call [before] before saving
/// it and [after] once it's saved. A budget that crossed 80% or 100% gets a
/// notification (it stays in the phone's tray), and the message comes back
/// for the screen to show in place of "added".
class BudgetAlerts {
  BudgetAlerts(this._ref);
  final Ref _ref;

  bool get _on =>
      _ref.read(featureFlagsProvider).value?.contains('personalBudgets') ??
      false;

  BudgetsOverview? before() =>
      _on ? _ref.read(personalBudgetsProvider).value : null;

  Future<String?> after(BudgetsOverview? before, String category) async {
    if (!_on) return null;
    final BudgetsOverview now;
    try {
      now = await _ref.read(personalBudgetsProvider.future);
    } catch (_) {
      return null; // No alert beats a failed save message.
    }
    final alerts = budgetAlerts(before, now, category);
    if (alerts.isEmpty) return null;
    final text = message(alerts.first);
    if (PushService.isSupportedPlatform) {
      await PushService.instance.showLocal(
        id: alerts.first.budget.category.hashCode,
        title: alerts.first.level == BudgetLevel.over
            ? AppStrings.budgetOverTitle
            : AppStrings.budgetNearTitle,
        body: text,
        payload: 'type=PERSONAL_BUDGET',
      );
    }
    return text;
  }

  /// "Food: ₹4,100 of ₹4,000 (102%)".
  static String message(BudgetAlert alert) {
    final b = alert.budget;
    final name = b.isTotal
        ? AppStrings.budgetMonth
        : CategoryModel.fromId(b.category)!.name;
    return '$name: ${CurrencyFormatter.format(b.spent, currency: '₹')} '
        '${AppStrings.budgetOf} '
        '${CurrencyFormatter.format(b.amount, currency: '₹')} '
        '(${(b.used * 100).round()}%)';
  }
}

final budgetAlertsProvider = Provider<BudgetAlerts>(BudgetAlerts.new);
