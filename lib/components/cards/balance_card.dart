import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../text/currency_text.dart';

/// Hero balance card showing total balance and breakdown
class BalanceCard extends StatelessWidget {
  final double totalBalance;
  final double youAreOwed;
  final double youOwe;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onOwedTap;
  final VoidCallback? onOweTap;

  const BalanceCard({
    Key? key,
    required this.totalBalance,
    this.youAreOwed = 0,
    this.youOwe = 0,
    this.currency = '₹',
    this.onTap,
    this.onOwedTap,
    this.onOweTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.divider(isDark),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.divider(isDark).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                'Overall Balance',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              // Large balance amount with animation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: CurrencyText(
                      totalBalance,
                      currency: currency,
                      textStyle: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(isDark),
                      ),
                      animated: true,
                      overrideColor: AppColors.textPrimary(isDark),
                    ),
                  ),
                  // Status badge
                  _buildStatusBadge(isDark),
                ],
              ),
              const SizedBox(height: 20),
              // Breakdown chips with proper gap
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onOwedTap,
                      child: _buildStatChip(
                        isDark: isDark,
                        icon: '✨',
                        label: 'You are owed',
                        amount: youAreOwed,
                        color: AppColors.greenLight,
                        currency: currency,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: onOweTap,
                      child: _buildStatChip(
                        isDark: isDark,
                        icon: '💸',
                        label: 'You owe',
                        amount: youOwe,
                        color: AppColors.warningOrange,
                        currency: currency,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
            ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    final isPositive = totalBalance >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.greenLight.withOpacity(0.15)
            : AppColors.warningOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPositive ? AppColors.greenLight : AppColors.warningOrange,
          width: 1,
        ),
      ),
      child: Text(
        isPositive ? 'You are owed' : 'You owe',
        style: AppTextStyles.caption(isDark).copyWith(
          color: isPositive ? AppColors.greenLight : AppColors.warningOrange,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required bool isDark,
    required String icon,
    required String label,
    required double amount,
    required Color color,
    required String currency,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.divider(isDark),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon $label',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          CurrencyText(
            amount,
            currency: currency,
            textStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
            overrideColor: AppColors.textPrimary(isDark),
          ),
        ],
      ),
    );
  }
}
