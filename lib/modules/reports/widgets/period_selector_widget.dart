import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/reports_provider.dart';

class PeriodSelectorWidget extends ConsumerWidget {
  const PeriodSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final period = ref.watch(reportsPeriodProvider);

    return Semantics(
      label: 'Report period selector',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPeriodChip(
              context,
              isDark,
              'Month',
              ReportsPeriod.month,
              period,
              ref,
            ),
            _buildPeriodChip(
              context,
              isDark,
              'Quarter',
              ReportsPeriod.quarter,
              period,
              ref,
            ),
            _buildPeriodChip(
              context,
              isDark,
              'Year',
              ReportsPeriod.year,
              period,
              ref,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(
    BuildContext context,
    bool isDark,
    String label,
    ReportsPeriod value,
    ReportsPeriod selected,
    WidgetRef ref,
  ) {
    final isSelected = value == selected;

    return Semantics(
      button: true,
      enabled: !isSelected,
      onTap: () => ref.read(reportsPeriodProvider.notifier).state = value,
      label: '$label period, ${isSelected ? 'selected' : 'not selected'}',
      child: GestureDetector(
        onTap: () => ref.read(reportsPeriodProvider.notifier).state = value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.divider(isDark),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body2(isDark).copyWith(
              fontSize: 13,
              color: isSelected ? Colors.white : AppColors.textPrimary(isDark),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
