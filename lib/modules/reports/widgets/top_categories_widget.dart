import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/reports_provider.dart';

class TopCategoriesWidget extends StatelessWidget {
  final ReportsData report;

  const TopCategoriesWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive spacing
    final isLarge = screenWidth > 1100;
    final margin = isLarge ? const EdgeInsets.only(left: 12) : const EdgeInsets.all(16);
    final padding = isLarge ? const EdgeInsets.all(12) : const EdgeInsets.all(16);

    return Semantics(
      label: 'Top spending categories list',
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Categories',
              style: AppTextStyles.headline3(isDark).copyWith(fontSize: 16),
            ),
            const SizedBox(height: 10),
            for (final category in report.topCategories)
              Semantics(
                label: '${category.category}, ₹${CurrencyFormatter.format(category.amount)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.category,
                              style: AppTextStyles.body2(isDark),
                            ),
                            Container(
                              height: 4,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: AppColors.divider(isDark),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                widthFactor: category.amount / report.totalSpending,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.brand,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.compact(category.amount),
                        style: AppTextStyles.body2(isDark).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
