import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/reports_provider.dart';

class StatsSummaryWidget extends StatelessWidget {
  final ReportsData report;

  const StatsSummaryWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive layout
    final isCompact = screenWidth < 600;
    final isLarge = screenWidth > 1100;

    final horizontalPadding = isLarge ? 0.0 : (isCompact ? 16.0 : 24.0);
    final verticalPadding = isLarge ? 8.0 : (isCompact ? 12.0 : 16.0);
    final spaceBetween = isLarge ? 12.0 : (isCompact ? 8.0 : 12.0);

    return Semantics(
      label: 'Spending summary statistics',
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: isLarge
            ? // Large: 3 cards in a row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    isDark,
                    'Total Spending',
                    report.totalSpending,
                    AppColors.brand,
                  ),
                ),
                SizedBox(width: spaceBetween),
                Expanded(
                  child: _buildStatCard(
                    context,
                    isDark,
                    'You Owe',
                    report.totalYouOwe,
                    AppColors.warning,
                  ),
                ),
                SizedBox(width: spaceBetween),
                Expanded(
                  child: _buildStatCard(
                    context,
                    isDark,
                    'Owed to You',
                    report.totalOwed,
                    AppColors.success,
                  ),
                ),
              ],
            )
            : // Compact/Standard: Stacked layout
            Column(
              children: [
                // Total Spending (Full width)
                _buildStatCard(
                  context,
                  isDark,
                  'Total Spending',
                  report.totalSpending,
                  AppColors.brand,
                ),
                SizedBox(height: spaceBetween),
                // You Owe + Owed to You (2 columns)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        isDark,
                        'You Owe',
                        report.totalYouOwe,
                        AppColors.warning,
                      ),
                    ),
                    SizedBox(width: spaceBetween),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        isDark,
                        'Owed to You',
                        report.totalOwed,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    bool isDark,
    String label,
    double amount,
    Color color,
  ) {
    return Semantics(
      label: '$label: ${CurrencyFormatter.format(amount)}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption(isDark),
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.format(amount),
              style: AppTextStyles.headline3(isDark).copyWith(
                color: color,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
