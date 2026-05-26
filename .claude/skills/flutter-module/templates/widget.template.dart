// Template: frontend/lib/modules/<feature>/widgets/<feature>_card_widget.dart
//
// Stateless, theme-aware, accepts data via the constructor. NO business logic.
// Width-aware: adapts padding/typography to screen width.

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../models/<feature>_model.dart';

class <Feature>CardWidget extends StatelessWidget {
  const <Feature>CardWidget({
    super.key,
    required this.item,
    this.onTap,
  });

  final <Feature>Model item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth < 600
        ? const EdgeInsets.all(12)
        : screenWidth < 1100
            ? const EdgeInsets.all(16)
            : const EdgeInsets.all(20);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.toString(),
                style: AppTextStyles.bodyMedium(isDark),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
