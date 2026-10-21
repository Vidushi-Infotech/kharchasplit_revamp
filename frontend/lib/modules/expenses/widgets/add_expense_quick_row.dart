import 'package:flutter/material.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Single-line quick-row used in the form body for Paid by / Split / When /
/// Category / Receipt / Notes. Icon + label + value + chevron, fully tappable.
class AddExpenseQuickRow extends StatelessWidget {
  const AddExpenseQuickRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
    this.valueIsMuted = false,
    this.errorText,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final bool valueIsMuted;
  final VoidCallback onTap;

  /// When non-null, the row is in an error state: the value renders red and
  /// this message is shown beneath the row so the user knows what to fix.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final errorColor = AppColors.errorText(isDark);
    final valueColor = hasError
        ? errorColor
        : (valueIsMuted
              ? AppColors.textSecondary(isDark)
              : AppColors.textPrimary(isDark));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.instance.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.body2(isDark).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: valueColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: hasError
                        ? errorColor
                        : AppColors.textSecondary(isDark),
                  ),
                ],
              ),
              if (hasError) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 13,
                        color: errorColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          errorText!,
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: errorColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AddExpenseRowDivider extends StatelessWidget {
  const AddExpenseRowDivider({super.key, required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.divider(isDark).withValues(alpha: 0.6),
      ),
    );
  }
}
