import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/user_model.dart';

/// Centre of the Record a payment screen (Splitwise style):
/// (you) → (them), "You paid Asha K." and the big editable amount in the
/// "money received" green. [amountController] is owned by the screen.
class RecordPaymentHeader extends StatelessWidget {
  const RecordPaymentHeader({
    super.key,
    required this.isDark,
    required this.me,
    required this.recipient,
    required this.currency,
    required this.amountController,
  });

  final bool isDark;
  final UserModel? me;
  final UserModel? recipient;

  /// Group currency (ISO code or symbol); '₹' until a group is picked.
  final String currency;
  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    final name = recipient?.name ?? '';
    final symbol = CurrencyFormatter.symbolFor(currency);
    final big = AppTextStyles.body1(isDark).copyWith(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: AppColors.owed,
      letterSpacing: -0.6,
    );

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarWidget(
              name: me?.name ?? '',
              imageUrl: me?.avatarUrl,
              radius: 32,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 28,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            AvatarWidget(
              name: name,
              imageUrl: recipient?.avatarUrl,
              radius: 32,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name.isEmpty
              ? AppStrings.recordAPayment
              : AppStrings.youPaidName(NameFormat.short(name)),
          textAlign: TextAlign.center,
          style: AppTextStyles.body1(
            isDark,
          ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Semantics(
            label: AppStrings.paymentAmountLabel,
            textField: true,
            child: TextFormField(
              controller: amountController,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: big,
              decoration: InputDecoration(
                prefixText: symbol,
                prefixStyle: big,
                hintText: '0.00',
                hintStyle: big.copyWith(color: AppColors.textSecondary(isDark)),
                isDense: true,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.owed, width: 2),
                ),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return AppStrings.amountMustBePositive;
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }
}
