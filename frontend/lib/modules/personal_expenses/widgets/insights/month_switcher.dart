import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// ‹ October 2026 › — steps the Insights month. No going past this month.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    final label = DateFormat(
      month.year == now.year ? 'MMMM' : 'MMMM yyyy',
    ).format(month);

    void step(int delta) {
      HapticService.instance.selection();
      onChanged(DateTime(month.year, month.month + delta));
    }

    return Row(
      children: [
        _Arrow(
          icon: Icons.chevron_left_rounded,
          label: 'Previous month',
          onTap: () => step(-1),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        _Arrow(
          icon: Icons.chevron_right_rounded,
          label: 'Next month',
          onTap: isCurrent ? null : () => step(1),
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.cardBg(isDark),
        side: BorderSide(color: AppColors.divider(isDark)),
      ),
      icon: Icon(icon, color: AppColors.textPrimary(isDark)),
      disabledColor: AppColors.textSecondary(isDark).withValues(alpha: 0.3),
    );
  }
}
