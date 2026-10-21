import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'add_expense_top_bar.dart';

/// Edit-mode placeholder shown while the existing expense is being fetched
/// (spinner) or after the fetch failed ([hydrateError] + Retry).
class AddExpenseHydrateView extends StatelessWidget {
  const AddExpenseHydrateView({
    super.key,
    required this.isDark,
    required this.hydrateError,
    required this.onClose,
    required this.onRetry,
  });

  final bool isDark;
  final String? hydrateError;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AddExpenseTopBar(
        title: 'Edit expense',
        onClose: onClose,
        isDark: isDark,
      ),
      body: Center(
        child: hydrateError != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load expense',
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hydrateError!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2(
                        isDark,
                      ).copyWith(color: AppColors.textSecondary(isDark)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        onRetry();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
