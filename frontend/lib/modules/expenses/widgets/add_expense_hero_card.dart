import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Top card of the Add/Edit expense form: big amount input + title field.
///
/// [titleController] is owned (and disposed) by the screen; the title
/// debounce also lives there and is driven through [onTitleChanged].
/// With `currencyConversion`, the currency symbol opens the currency
/// picker and an amount in another currency shows its conversion below.
class AddExpenseHeroCard extends ConsumerWidget {
  const AddExpenseHeroCard({
    super.key,
    required this.isDark,
    required this.state,
    required this.autoFocus,
    required this.showValidation,
    required this.titleController,
    required this.onAmountChanged,
    required this.onTitleChanged,
  });

  final bool isDark;
  final AddExpenseState state;
  final bool autoFocus;
  final bool showValidation;
  final TextEditingController titleController;
  final ValueChanged<double> onAmountChanged;
  final ValueChanged<String> onTitleChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleError = showValidation && (state.title ?? '').trim().isEmpty;
    // The group's currency (symbol or code); null until the group loads.
    final groupCurrency = state.groupId == null
        ? null
        : ref.watch(groupDetailProvider(state.groupId!)).value?.group.currency;
    final fxOn =
        watchFeature(ref, 'currencyConversion') && groupCurrency != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          Semantics(
            label:
                'Enter amount in ${state.currency}, currently ${CurrencyFormatter.format(state.amount, currency: state.currency)}',
            child: AmountInputWidget(
              amount: state.amount,
              currency: state.currency,
              autoFocus: autoFocus,
              hasError: showValidation && state.amount <= 0,
              onChanged: (amount) {
                onAmountChanged(amount);
              },
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
          if (fxOn && state.entryCurrency != null) ...[
            const SizedBox(height: 6),
            FxPreviewLine(
              isDark: isDark,
              state: state,
              groupCurrency: groupCurrency,
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            color: AppColors.divider(isDark).withValues(alpha: 0.5),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: titleController,
              textAlign: TextAlign.center,
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: titleError ? 'Add a title' : "What's this for?",
                hintStyle: AppTextStyles.body1(isDark).copyWith(
                  color: titleError
                      ? AppColors.errorText(isDark)
                      : AppColors.textSecondary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                onTitleChanged(value);
              },
            ),
          ),
          if (titleError) ...[
            const SizedBox(height: 2),
            Text(
              'Title is required',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.errorText(isDark),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
