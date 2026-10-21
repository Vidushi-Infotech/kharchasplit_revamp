import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "Did your ₹X payment to {name} go through?" — asked after the user comes
/// back from their UPI app. Resolves true only on "Yes, record ₹X"; the UPI
/// app's own result is never trusted.
Future<bool> showUpiPaidConfirmDialog(
  BuildContext context, {
  required String amountLabel,
  required String payeeName,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppStrings.didUpiPaymentGoThrough(amountLabel, payeeName),
        style: AppTextStyles.body1(
          isDark,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      content: Text(
        AppStrings.upiCheckYourApp,
        style: AppTextStyles.body2(
          isDark,
        ).copyWith(color: AppColors.textSecondary(isDark)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary(isDark),
          ),
          child: const Text(AppStrings.upiNotPaid),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          child: Text(AppStrings.yesRecordAmount(amountLabel)),
        ),
      ],
    ),
  );
  return result ?? false;
}
