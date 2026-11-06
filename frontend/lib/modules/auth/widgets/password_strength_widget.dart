import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Password strength indicator with 4-segment bar
class PasswordStrengthWidget extends StatelessWidget {
  final String password;

  const PasswordStrengthWidget({
    Key? key,
    required this.password,
  }) : super(key: key);

  /// Calculate password strength (0-4)
  int _calculateStrength() {
    int strength = 0;

    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;

    return strength;
  }

  /// Get strength label and color
  String _getStrengthLabel() {
    final strength = _calculateStrength();
    switch (strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  Color _getStrengthColor() {
    final strength = _calculateStrength();
    switch (strength) {
      case 0:
      case 1:
        return AppColors.errorText(false);
      case 2:
        return AppColors.orange;
      case 3:
        return AppColors.tealDark;
      case 4:
        return AppColors.greenLight;
      default:
        return AppColors.divider(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strength = _calculateStrength();

    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Strength bar
        Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: index < strength
                      ? _getStrengthColor()
                      : AppColors.divider(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Strength label
        Text(
          'Password Strength: ${_getStrengthLabel()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getStrengthColor(),
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
