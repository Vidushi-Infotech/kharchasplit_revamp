import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';

class ProfileStatsWidget extends StatelessWidget {
  final int totalExpenses;
  final int totalGroups;
  final double totalSpent;

  const ProfileStatsWidget({
    super.key,
    required this.totalExpenses,
    required this.totalGroups,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive grid
    final isCompact = screenWidth < 600;

    return Semantics(
      label: 'Profile statistics',
      child: isCompact
          ? Column(
              children: [
                _buildStatCard(isDark, 'Total Expenses', totalExpenses.toString(),
                    Icons.receipt_long_rounded, AppColors.brand),
                const SizedBox(height: 12),
                _buildStatCard(isDark, 'Groups', totalGroups.toString(),
                    Icons.groups_rounded, AppColors.success),
                const SizedBox(height: 12),
                _buildStatCard(isDark, 'Total Spent', CurrencyFormatter.format(totalSpent),
                    Icons.trending_down_rounded, AppColors.warning),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildStatCard(isDark, 'Total Expenses',
                      totalExpenses.toString(), Icons.receipt_long_rounded, AppColors.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(isDark, 'Groups', totalGroups.toString(),
                      Icons.groups_rounded, AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(isDark, 'Total Spent',
                      CurrencyFormatter.format(totalSpent), Icons.trending_down_rounded, AppColors.warning),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.headline2(isDark).copyWith(
              fontSize: 24,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
