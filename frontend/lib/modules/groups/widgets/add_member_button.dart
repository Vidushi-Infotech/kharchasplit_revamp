import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Small pill-style "+ Add" button that lives next to the Members header.
/// Replaces the (removed) "Add member" item from the 3-dot menu.
class AddMemberButton extends StatelessWidget {
  const AddMemberButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.brand.withValues(alpha: isDark ? 0.18 : 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: AppColors.brand),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700, color: AppColors.brand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
