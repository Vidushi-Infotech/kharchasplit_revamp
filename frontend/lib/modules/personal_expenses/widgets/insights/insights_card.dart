import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The card every Insights section sits in: a small caps title, an
/// optional note on the right, then the content.
class InsightsCard extends StatelessWidget {
  const InsightsCard({
    super.key,
    required this.title,
    required this.child,
    this.note,
  });

  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final caption = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark), fontSize: 11);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              if (note != null) Text(note!, style: caption),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
