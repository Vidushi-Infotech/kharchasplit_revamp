import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/add_expense_fx.dart';
import '../state/add_expense_provider.dart';
import 'amount_input_widget.dart';
import 'currency_picker_sheet.dart';
import 'fx_preview_line.dart';

/// Description and amount rows of the Add/Edit expense form, Splitwise
/// style: a category tile button left of an underlined description field,
/// and a currency button left of a big underlined amount.
///
/// [titleController] is owned (and disposed) by the screen; the title
/// debounce also lives there and is driven through [onTitleChanged].
/// With `currencyConversion`, the currency button opens the currency picker
/// and an amount in another currency shows its conversion below.
class AddExpenseMainFields extends ConsumerWidget {
  const AddExpenseMainFields({
    super.key,
    required this.isDark,
    required this.state,
    required this.autoFocus,
    required this.showValidation,
    required this.titleController,
    required this.onAmountChanged,
    required this.onTitleChanged,
    required this.onCategoryTap,
  });

  final bool isDark;
  final AddExpenseState state;
  final bool autoFocus;
  final bool showValidation;
  final TextEditingController titleController;
  final ValueChanged<double> onAmountChanged;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleError = showValidation && (state.title ?? '').trim().isEmpty;
    // The group's currency (symbol or code); null until the group loads.
    final groupCurrency = state.groupId == null
        ? null
        : ref.watch(groupDetailProvider(state.groupId!)).value?.group.currency;
    final fxOn =
        watchFeature(ref, 'currencyConversion') && groupCurrency != null;
    final category = state.category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: category == null
                  ? AppStrings.chooseCategory
                  : '${category.name}. ${AppStrings.chooseCategory}',
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCategoryTap,
                  borderRadius: BorderRadius.circular(10),
                  child: category == null
                      ? CategoryTile(
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.textSecondary(isDark),
                        )
                      : CategoryTile.forCategory(category),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: AppStrings.enterDescription,
                  hintStyle: AppTextStyles.body1(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 18,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.only(bottom: 6),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: titleError
                          ? AppColors.errorText(isDark)
                          : AppColors.inputBorder(isDark),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: titleError
                          ? AppColors.errorText(isDark)
                          : AppColors.brand,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: onTitleChanged,
              ),
            ),
          ],
        ),
        if (titleError)
          Padding(
            padding: const EdgeInsets.only(left: 58, top: 4),
            child: Text(
              AppStrings.descriptionRequired,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.errorText(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Semantics(
          label:
              'Enter amount in ${state.currency}, currently '
              '${CurrencyFormatter.format(state.amount, currency: state.currency)}',
          child: AmountInputWidget(
            amount: state.amount,
            currency: state.currency,
            autoFocus: autoFocus,
            hasError: showValidation && state.amount <= 0,
            onChanged: onAmountChanged,
            onCurrencyTap: fxOn
                ? () => showCurrencyPickerSheet(
                    context,
                    isDark: isDark,
                    groupCurrency: groupCurrency,
                  )
                : null,
            currencyTapLabel: AppStrings.currencyTapToChange(
              addExpenseEntryCode(state, groupCurrency),
            ),
          ),
        ),
        if (fxOn && state.entryCurrency != null)
          Padding(
            padding: const EdgeInsets.only(left: 58, top: 6),
            child: FxPreviewLine(
              isDark: isDark,
              state: state,
              groupCurrency: groupCurrency,
            ),
          ),
      ],
    );
  }
}
