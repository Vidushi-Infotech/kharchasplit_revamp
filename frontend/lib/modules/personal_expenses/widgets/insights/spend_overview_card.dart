import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/personal_summary_model.dart';

/// The month at a glance: what was spent, how that compares with last
/// month, and (with any income) how much of it was kept.
class SpendOverviewCard extends StatelessWidget {
  const SpendOverviewCard({super.key, required this.summary});

  final PersonalSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final previous = DateFormat(
      'MMMM',
    ).format(DateTime(s.month.year, s.month.month - 1));
    final saved = s.income - s.spent;
    final rate = s.income > 0 ? saved / s.income : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealLight, AppColors.tealDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.insightsSpent.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(s.spent, currency: '₹'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          _ChangeChip(change: s.spentChange, against: previous),
          if (s.income > 0) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                _Small(
                  label: AppStrings.personalIncome,
                  value: CurrencyFormatter.format(s.income, currency: '₹'),
                ),
                _Small(
                  label: saved >= 0
                      ? AppStrings.insightsSaved
                      : AppStrings.insightsOverspent,
                  value: CurrencyFormatter.format(saved.abs(), currency: '₹'),
                ),
                if (rate != null && rate > 0)
                  _Small(
                    label: AppStrings.insightsSavingsRate,
                    value: '${(rate * 100).round()}%',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.change, required this.against});

  final double? change;
  final String against;

  @override
  Widget build(BuildContext context) {
    final c = change;
    final String text;
    IconData? icon;
    if (c == null) {
      text = AppStrings.insightsNothingToCompare(against);
    } else if (c.abs() < 0.005) {
      text = AppStrings.insightsSameAs(against);
    } else {
      icon = c > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
      text =
          '${(c.abs() * 100).round()}% '
          '${c > 0 ? AppStrings.insightsMoreThan : AppStrings.insightsLessThan} '
          '$against';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Small extends StatelessWidget {
  const _Small({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption(isDark).copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
