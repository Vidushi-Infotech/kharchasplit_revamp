import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

/// Month over day ("Oct" / "18") at the start of an expense row.
class DateBadge extends StatelessWidget {
  const DateBadge(this.date, {super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final color = AppColors.textSecondary(isDark);
    return SizedBox(
      width: 34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('MMM').format(date),
            style: textTheme.labelSmall?.copyWith(color: color, height: 1.1),
          ),
          Text(
            '${date.day}',
            style: textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
