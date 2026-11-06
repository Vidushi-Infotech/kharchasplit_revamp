import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Drag handle shown at the top of every Add-expense bottom sheet.
class AddExpenseSheetHandle extends StatelessWidget {
  const AddExpenseSheetHandle({super.key, required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider(isDark),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Title row (with optional trailing action) for Add-expense bottom sheets.
class AddExpenseSheetTitle extends StatelessWidget {
  const AddExpenseSheetTitle({
    super.key,
    required this.text,
    required this.isDark,
    this.trailing,
  });
  final String text;
  final bool isDark;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
