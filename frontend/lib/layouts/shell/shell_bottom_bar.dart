import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';

/// "Add expense" pill that floats bottom-right on the Groups, Friends and
/// Activity tabs.
class ShellAddExpenseButton extends StatelessWidget {
  const ShellAddExpenseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'shell_add_expense',
      onPressed: () {
        HapticService.instance.tap();
        onPressed();
      },
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.receipt_long_rounded),
      label: const Text(AppStrings.addExpense),
    );
  }
}
