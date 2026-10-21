import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_catalog.dart';
import '../state/add_expense_fx.dart';
import '../state/add_expense_provider.dart';
import '../state/currency_recents_provider.dart';
import 'add_expense_sheet_header.dart';

/// "Currency" sheet of the Add expense amount (`currencyConversion`): the
/// group's currency first, then recently used, then every currency the
/// server can convert ([CurrencyCatalog]). Picking one writes it into
/// [addExpenseProvider]; amount, payers and split are then entered in it.
void showCurrencyPickerSheet(
  BuildContext context, {
  required bool isDark,
  required String groupCurrency,
}) {
  showAdaptiveSheet<void>(
    context: context,
    size: AdaptiveSheetSize.small,
    // Above the floating tab bar.
    useRootNavigator: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) =>
        _CurrencyPickerBody(isDark: isDark, groupCurrency: groupCurrency),
  );
}

class _CurrencyPickerBody extends ConsumerWidget {
  const _CurrencyPickerBody({
    required this.isDark,
    required this.groupCurrency,
  });

  final bool isDark;

  /// The group's currency as stored on the group (symbol or code).
  final String groupCurrency;

  void _pick(BuildContext context, WidgetRef ref, String code) {
    HapticService.instance.selection();
    final notifier = ref.read(addExpenseProvider.notifier);
    notifier.state = addExpenseWithCurrency(
      notifier.state,
      code,
      groupCurrency,
    );
    if (code != groupCurrencyCode(groupCurrency)) {
      ref.read(currencyRecentsProvider.notifier).use(code);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupCode = groupCurrencyCode(groupCurrency);
    final recent = ref.watch(currencyRecentsProvider);
    final selected = addExpenseEntryCode(
      ref.watch(addExpenseProvider),
      groupCurrency,
    );
    final items = CurrencyCatalog.pickerOrder(groupCode, recent);
    final recentSet = recent.toSet();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AddExpenseSheetHandle(isDark: isDark),
            AddExpenseSheetTitle(
              text: AppStrings.currencyTitle,
              isDark: isDark,
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  final note = c.code == groupCode
                      ? AppStrings.currencyGroupDefault
                      : recentSet.contains(c.code)
                      ? AppStrings.currencyRecent
                      : null;
                  final isSelected = c.code == selected;
                  return ListTile(
                    selected: isSelected,
                    onTap: () => _pick(context, ref, c.code),
                    leading: SizedBox(
                      width: 44,
                      child: Text(
                        c.symbol,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                    title: Text(
                      '${c.code} · ${c.name}',
                      style: AppTextStyles.body1(isDark),
                    ),
                    subtitle: note == null
                        ? null
                        : Text(
                            note,
                            style: AppTextStyles.caption(
                              isDark,
                            ).copyWith(color: AppColors.textSecondary(isDark)),
                          ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.tealDark,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
