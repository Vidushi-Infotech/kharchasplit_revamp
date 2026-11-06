import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/models.dart';

/// One person on the Split options screen: tick box, avatar, name (with
/// an "Owes ₹X · 40% of total" caption for exact amounts) and the value
/// field for the split type. State lives in [SplitBreakdownWidget].
class SplitMemberRow extends StatelessWidget {
  const SplitMemberRow({
    super.key,
    required this.member,
    required this.controller,
    required this.included,
    required this.value,
    required this.splitType,
    required this.totalAmount,
    required this.currency,
    required this.isMe,
    required this.onToggle,
    required this.onChanged,
  });

  final UserModel member;
  final TextEditingController controller;
  final bool included;

  /// The member's current value in the form state.
  final double value;
  final SplitType splitType;
  final double totalAmount;
  final String currency;

  /// The signed-in user — shown as "Name (Me)".
  final bool isMe;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  static String _inputHint(SplitType type) {
    switch (type) {
      case SplitType.exact:
        return '0.00';
      case SplitType.percentage:
        return '0';
      case SplitType.shares:
        return '1';
      default:
        return '';
    }
  }

  static String _inputSuffix(SplitType type) {
    switch (type) {
      case SplitType.percentage:
        return '%';
      case SplitType.shares:
        return 'shares';
      default:
        return '';
    }
  }

  /// Invited people may not have a name yet.
  static String displayName(UserModel member) => member.name.trim().isEmpty
      ? AppStrings.invitedMember
      : member.name.trim();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncluded = included;
    final name = displayName(member);

    // For Unequally (Exact): show % of total + "Owes ₹X" caption under name.
    String? statusCaption;
    String? percentCaption;
    if (splitType == SplitType.exact && isIncluded) {
      if (totalAmount > 0) {
        final pct = value / totalAmount * 100;
        percentCaption = pct == pct.roundToDouble()
            ? '${pct.toStringAsFixed(0)}% of total'
            : '${pct.toStringAsFixed(1)}% of total';
      }
      statusCaption = value > 0
          ? AppStrings.owesAmount(
              CurrencyFormatter.format(value, currency: currency),
            )
          : 'Not yet assigned';
    } else if (!isIncluded) {
      statusCaption = AppStrings.notInThisSplit;
    }

    return GestureDetector(
      onTap: () => onToggle(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider(isDark), width: 0.6),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: isIncluded,
              tristate: false,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.brand,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            // Avatar
            AvatarWidget(name: name, imageUrl: member.avatarUrl, radius: 16),
            const SizedBox(width: 8),
            // Name + (Unequally only) status caption
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '$name (Me)' : name,
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: isIncluded
                          ? AppColors.textPrimary(isDark)
                          : AppColors.textSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (statusCaption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      statusCaption,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: value > 0
                            ? AppColors.success
                            : AppColors.textSecondary(isDark),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (percentCaption != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      percentCaption,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Equally: the per-head share is read-only, so plain text;
            // the other split types get the value field.
            Expanded(
              flex: 1,
              child: splitType == SplitType.equal
                  ? _EqualShareText(
                      controller: controller,
                      included: isIncluded,
                      currency: currency,
                    )
                  : TextField(
                      controller: controller,
                      enabled: isIncluded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: isIncluded
                            ? AppColors.textPrimary(isDark)
                            : AppColors.textSecondary(isDark),
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        prefixText: splitType == SplitType.exact
                            ? currency
                            : null,
                        suffixText: _inputSuffix(splitType),
                        hintText: _inputHint(splitType),
                        hintStyle: AppTextStyles.body2(
                          isDark,
                        ).copyWith(color: AppColors.textSecondary(isDark)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder(isDark),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder(isDark),
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: AppColors.divider(isDark),
                          ),
                        ),
                      ),
                      onChanged: (_) => onChanged(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The equal share as right-aligned text. Follows [controller], which the
/// breakdown widget refills whenever the amount or the people change.
class _EqualShareText extends StatelessWidget {
  const _EqualShareText({
    required this.controller,
    required this.included,
    required this.currency,
  });

  final TextEditingController controller;
  final bool included;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final share = included ? double.tryParse(value.text) ?? 0 : 0.0;
        return Text(
          CurrencyFormatter.format(share, currency: currency),
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body1(isDark).copyWith(
            fontWeight: FontWeight.w600,
            color: included && share > 0
                ? AppColors.textPrimary(isDark)
                : AppColors.textSecondary(isDark),
          ),
        );
      },
    );
  }
}
