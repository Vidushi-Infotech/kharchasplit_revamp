import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "UPI ID" row on the Account screen: shows the saved ID, or "Add" when
/// there is none. Either way a tap opens Edit profile, where it's set.
/// Styled like the settings rows around it.
class UpiIdRow extends StatelessWidget {
  const UpiIdRow({super.key, required this.upiId, required this.isDark});

  final String? upiId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final value = upiId?.trim() ?? '';
    final hasValue = value.isNotEmpty;
    return Semantics(
      button: true,
      label: hasValue
          ? '${AppStrings.upiId}: $value'
          : '${AppStrings.addUpiId} ${AppStrings.upiId}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.pushNamed('edit-profile'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface(isDark),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppColors.divider(isDark).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 17,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppStrings.upiId,
                  style: AppTextStyles.body1(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value : AppStrings.addUpiId,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: hasValue
                          ? AppColors.textSecondary(isDark)
                          : AppColors.brand,
                      fontWeight: hasValue ? FontWeight.w400 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
