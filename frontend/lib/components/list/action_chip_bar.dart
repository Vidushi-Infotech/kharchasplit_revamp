import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// One button in an [ActionChipBar].
class ActionChipItem {
  const ActionChipItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// The filled (orange) chip, e.g. "Settle up".
  final bool primary;
}

/// Horizontally scrolling row of pill buttons under the group header:
/// Settle up · Balances · Totals · Export…
class ActionChipBar extends StatelessWidget {
  const ActionChipBar({super.key, required this.items});

  final List<ActionChipItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final fg = item.primary ? Colors.white : AppColors.textPrimary(isDark);
          return Center(
            child: Material(
              color: item.primary ? AppColors.owe : AppColors.surface(isDark),
              shape: StadiumBorder(
                side: item.primary
                    ? BorderSide.none
                    : BorderSide(color: AppColors.divider(isDark)),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: item.onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null) ...[
                        Icon(item.icon, size: 16, color: fg),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        item.label,
                        style: textTheme.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
