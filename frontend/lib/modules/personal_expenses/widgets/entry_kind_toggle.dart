import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';

/// Expense | Income switch at the top of the add form: a pill whose
/// highlight slides to the chosen side, orange for money out and green for
/// money in (the colours the list uses for each).
class EntryKindToggle extends StatelessWidget {
  const EntryKindToggle({
    super.key,
    required this.isIncome,
    required this.onChanged,
  });

  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isIncome ? AppColors.success : AppColors.warning;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: isIncome ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.28 : 0.16),
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _Side(
                label: AppStrings.personalExpense,
                icon: Icons.arrow_upward_rounded,
                selected: !isIncome,
                color: AppColors.warning,
                onTap: () => _pick(false),
              ),
              _Side(
                label: AppStrings.personalIncome,
                icon: Icons.arrow_downward_rounded,
                selected: isIncome,
                color: AppColors.success,
                onTap: () => _pick(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _pick(bool income) {
    if (income == isIncome) return;
    HapticService.instance.selection();
    onChanged(income);
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected ? color : AppColors.textSecondary(isDark);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
