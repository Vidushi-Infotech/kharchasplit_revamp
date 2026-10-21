import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

/// One member with an amount field — used by the "Multiple people" payer
/// sheet and the "By adjustment" split. Optional tick box (who's in) and a
/// ± button that flips the sign (signed amounts, e.g. adjustments; many
/// phone keypads have no minus key).
class AddExpenseMemberAmountRow extends StatelessWidget {
  const AddExpenseMemberAmountRow({
    super.key,
    required this.member,
    required this.label,
    required this.controller,
    required this.fieldLabel,
    required this.onChanged,
    this.caption,
    this.captionColor,
    this.included,
    this.onIncludedChanged,
    this.signed = false,
    this.currency = '₹',
  });

  final UserModel member;

  /// Display name, e.g. "Asha" or "Ravi (Me)".
  final String label;
  final TextEditingController controller;

  /// Screen-reader label of the amount field.
  final String fieldLabel;
  final VoidCallback onChanged;
  final String? caption;
  final Color? captionColor;

  /// Non-null shows a tick box; false greys the row and disables the field.
  final bool? included;
  final ValueChanged<bool>? onIncludedChanged;
  final bool signed;

  /// Symbol in front of the amount (the form's entry currency).
  final String currency;

  void _flipSign() {
    final t = controller.text.trim();
    final flipped = t.startsWith('-') ? t.substring(1) : '-$t';
    controller.value = TextEditingValue(
      text: flipped,
      selection: TextSelection.collapsed(offset: flipped.length),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = included ?? true;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
    );
    return Container(
      color: enabled
          ? Colors.transparent
          : AppColors.textSecondary(isDark).withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (included != null)
            Checkbox(
              value: included,
              onChanged: (v) => onIncludedChanged?.call(v ?? false),
              activeColor: AppColors.brand,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          AvatarWidget(
            name: member.name,
            imageUrl: member.avatarUrl,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2(isDark).copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.textPrimary(isDark)
                        : AppColors.textSecondary(isDark),
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(isDark).copyWith(
                      fontSize: 11,
                      color: captionColor ?? AppColors.textSecondary(isDark),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (signed)
            Semantics(
              button: true,
              label: AppStrings.flipAdjustmentSign,
              child: IconButton(
                onPressed: enabled ? _flipSign : null,
                icon: const Icon(Icons.exposure_rounded, size: 20),
                color: AppColors.brand,
                visualDensity: VisualDensity.compact,
                tooltip: AppStrings.flipAdjustmentSign,
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Semantics(
                label: fieldLabel,
                textField: true,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: signed,
                  ),
                  style: AppTextStyles.body2(isDark),
                  decoration: InputDecoration(
                    prefixText: currency,
                    hintText: '0',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: border,
                    enabledBorder: border,
                    disabledBorder: border.copyWith(
                      borderSide: BorderSide(color: AppColors.divider(isDark)),
                    ),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
