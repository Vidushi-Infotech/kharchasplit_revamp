import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/inputs/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/category_model.dart';
import '../../../../models/personal_budget_model.dart';
import '../../state/personal_budgets_provider.dart';

/// Set, change or remove one budget. Opened on a budget (or a category
/// without one) it edits that; opened from "Add budget" it first asks
/// which category, offering only those without a budget yet.
class BudgetEditorSheet extends ConsumerStatefulWidget {
  const BudgetEditorSheet({super.key, this.category});

  /// [BudgetStatus.total], an expense category id, or null to pick one.
  final String? category;

  static Future<void> show(BuildContext context, {String? category}) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the floating tab bar.
      useRootNavigator: true,
      isScrollControlled: true,
      // Tall ones stop below the status bar.
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: AppColors.surface(
        Theme.of(context).brightness == Brightness.dark,
      ),
      builder: (_) => BudgetEditorSheet(category: category),
    );
  }

  @override
  ConsumerState<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends ConsumerState<BudgetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String? _category = widget.category;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    if (existing != null) {
      _amount.text = existing.amount == existing.amount.roundToDouble()
          ? existing.amount.toStringAsFixed(0)
          : existing.amount.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  BudgetsOverview? get _overview => ref.read(personalBudgetsProvider).value;

  BudgetStatus? get _existing =>
      _category == null ? null : _overview?.of(_category!);

  /// Categories that can get a new budget: the whole month and each
  /// expense category, minus those that have one.
  List<String> get _free {
    final taken = {for (final b in _overview?.budgets ?? const []) b.category};
    return [
      BudgetStatus.total,
      for (final c in CategoryModel.all) c.id,
    ].where((id) => !taken.contains(id)).toList();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      HapticService.instance.success();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppStrings.budgetSaveFailed;
        });
      }
    }
  }

  void _save() {
    if (_category == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final amount = double.parse(_amount.text.trim());
    _run(
      () => ref
          .read(personalBudgetsProvider.notifier)
          .setBudget(_category!, amount),
      AppStrings.budgetSaved,
    );
  }

  void _remove() => _run(
    () => ref.read(personalBudgetsProvider.notifier).removeBudget(_category!),
    AppStrings.budgetRemoved,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final existing = _existing;
    final picking = widget.category == null;
    final spent = _category == null
        ? 0.0
        : _category == BudgetStatus.total
        ? _overview?.totalSpent ?? 0
        : _overview?.spent[_category] ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing != null ? AppStrings.budgetEdit : AppStrings.budgetAdd,
              style: AppTextStyles.headline2(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (picking) ...[
              Text(
                AppStrings.budgetPickCategory,
                style: AppTextStyles.body2(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in _free)
                    ChoiceChip(
                      avatar: Icon(
                        _icon(id),
                        size: 16,
                        color: id == _category
                            ? Colors.white
                            : AppColors.textSecondary(isDark),
                      ),
                      label: Text(_name(id)),
                      selected: id == _category,
                      showCheckmark: false,
                      selectedColor: AppColors.brand,
                      labelStyle: TextStyle(
                        color: id == _category
                            ? Colors.white
                            : AppColors.textPrimary(isDark),
                      ),
                      onSelected: (_) => setState(() => _category = id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              Row(
                children: [
                  Icon(_icon(_category!), color: AppColors.brand),
                  const SizedBox(width: 10),
                  Text(
                    _name(_category!),
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            AppTextField(
              label: AppStrings.budgetAmount,
              hint: '0',
              controller: _amount,
              autofocus: !picking,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.currency_rupee_rounded,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                return n == null || n <= 0
                    ? 'Enter an amount greater than 0'
                    : null;
              },
            ),
            if (spent > 0) ...[
              const SizedBox(height: 6),
              Text(
                AppStrings.budgetSpentThisMonth(
                  CurrencyFormatter.format(spent, currency: '₹'),
                ),
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: AppColors.errorText(isDark)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || _category == null ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(AppStrings.budgetSet),
            ),
            if (existing != null)
              TextButton(
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorText(isDark),
                ),
                child: const Text(AppStrings.budgetRemove),
              ),
          ],
        ),
      ),
    );
  }

  static String _name(String id) => id == BudgetStatus.total
      ? AppStrings.budgetWholeMonth
      : CategoryModel.fromId(id)!.name;

  static IconData _icon(String id) => id == BudgetStatus.total
      ? Icons.savings_rounded
      : CategoryModel.fromId(id)!.icon;
}
