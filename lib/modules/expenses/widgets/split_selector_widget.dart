import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

class SplitSelectorWidget extends StatelessWidget {
  final SplitType splitType;
  final double amount;
  final Function(SplitType) onSplitTypeChanged;

  const SplitSelectorWidget({
    Key? key,
    required this.splitType,
    required this.amount,
    required this.onSplitTypeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How to split?', style: AppTextStyles.body2(isDark)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSplitTypeButton(
                isDark,
                label: 'Equal',
                type: SplitType.equal,
                isSelected: splitType == SplitType.equal,
                onTap: () => onSplitTypeChanged(SplitType.equal),
              ),
              const SizedBox(width: 12),
              _buildSplitTypeButton(
                isDark,
                label: 'Exact',
                type: SplitType.exact,
                isSelected: splitType == SplitType.exact,
                onTap: () => onSplitTypeChanged(SplitType.exact),
              ),
              const SizedBox(width: 12),
              _buildSplitTypeButton(
                isDark,
                label: 'Percentage',
                type: SplitType.percentage,
                isSelected: splitType == SplitType.percentage,
                onTap: () => onSplitTypeChanged(SplitType.percentage),
              ),
              const SizedBox(width: 12),
              _buildSplitTypeButton(
                isDark,
                label: 'Shares',
                type: SplitType.shares,
                isSelected: splitType == SplitType.shares,
                onTap: () => onSplitTypeChanged(SplitType.shares),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSplitTypeButton(
    bool isDark, {
    required String label,
    required SplitType type,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.divider(isDark),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
