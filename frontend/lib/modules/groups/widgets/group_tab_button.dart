import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Pill-shaped tab chip. Selected state: filled with brand teal + white
/// content. Unselected: transparent with muted text and a 60%-opacity
/// icon — matches the shadcn / Radix "rounded-full primary" tab pattern.
class GroupTabButton extends StatelessWidget {
  const GroupTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? Colors.white : AppColors.textSecondary(isDark);
    final Color iconColor = selected
        ? Colors.white
        : AppColors.textSecondary(isDark).withValues(alpha: 0.7);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.tealDark : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: selected
                  ? null
                  : Border.all(color: AppColors.divider(isDark)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.body2(isDark).copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : AppColors.tealDark.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.tealDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
