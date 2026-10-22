import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/settlement_model.dart';

/// Cash · UPI · Bank transfer · Other chips for the Record payment form.
/// Nothing is preselected: an unpicked method is sent as null rather than
/// recording a guess. Tapping the selected chip again clears it.
class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showLabel = true,
  });

  final SettlementMethod? selected;
  final ValueChanged<SettlementMethod?> onChanged;

  /// Off when the surrounding sheet already has a "Paid with" title.
  final bool showLabel;

  static const _order = [
    SettlementMethod.cash,
    SettlementMethod.upi,
    SettlementMethod.bankTransfer,
    SettlementMethod.other,
  ];

  static IconData _icon(SettlementMethod m) => switch (m) {
    SettlementMethod.cash => Icons.payments_outlined,
    SettlementMethod.upi => Icons.qr_code_rounded,
    SettlementMethod.bankTransfer => Icons.account_balance_outlined,
    SettlementMethod.other => Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            '${AppStrings.paymentMethod} (optional)',
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _order)
              Semantics(
                selected: selected == m,
                label: 'Paid with ${m.label}',
                child: ChoiceChip(
                  avatar: Icon(
                    _icon(m),
                    size: 16,
                    color: selected == m
                        ? Colors.white
                        : AppColors.textSecondary(isDark),
                  ),
                  label: Text(m.label),
                  selected: selected == m,
                  showCheckmark: false,
                  selectedColor: AppColors.brand,
                  backgroundColor: AppColors.cardBg(isDark),
                  side: BorderSide(
                    color: selected == m
                        ? AppColors.brand
                        : AppColors.divider(isDark),
                  ),
                  labelStyle: AppTextStyles.body2(isDark).copyWith(
                    color: selected == m
                        ? Colors.white
                        : AppColors.textPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (on) => onChanged(on ? m : null),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
