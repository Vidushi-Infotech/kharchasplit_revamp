import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Section title in a flat list, e.g. "October 2026" or "Group members".
class MonthSectionHeader extends StatelessWidget {
  const MonthSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      child: Container(
        width: double.infinity,
        color: AppColors.inputFill(isDark),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
