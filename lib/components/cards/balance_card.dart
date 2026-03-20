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

  const BalanceCard({
    Key? key,
    required this.totalBalance,
    this.youAreOwed = 0,
    this.youOwe = 0,
    this.currency = '₹',
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.tealDark,
                AppColors.tealDark.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDark.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                'Overall Balance',
                style: AppTextStyles.body2(true).copyWith(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
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
                        color: Colors.white,
                      ),
                      animated: true,
                      overrideColor: Colors.white,
                    ),
                  ),
                  // Status badge
                  _buildStatusBadge(isDark),
                ],
              ),
              const SizedBox(height: 24),
              // Breakdown chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(
                    icon: '✨',
                    label: 'You are owed',
                    amount: youAreOwed,
                    color: AppColors.greenLight,
                    currency: currency,
                  ),
                  _buildStatChip(
                    icon: '💸',
                    label: 'You owe',
                    amount: youOwe,
                    color: AppColors.warningOrange,
                    currency: currency,
                  ),
                ],
              ),
            ],
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
            ? AppColors.greenLight.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPositive ? 'You are owed' : 'You owe',
        style: AppTextStyles.caption(true).copyWith(
          color: isPositive ? AppColors.greenLight : Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String icon,
    required String label,
    required double amount,
    required Color color,
    required String currency,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$icon $label',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            CurrencyText(
              amount,
              currency: currency,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overrideColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
