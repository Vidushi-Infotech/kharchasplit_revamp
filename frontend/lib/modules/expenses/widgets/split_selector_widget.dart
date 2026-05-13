import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

class SplitSelectorWidget extends StatefulWidget {
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
  State<SplitSelectorWidget> createState() => _SplitSelectorWidgetState();
}

class _SplitSelectorWidgetState extends State<SplitSelectorWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How to split?', style: AppTextStyles.body2(isDark)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) {
                final splitTypes = [
                  SplitType.equal,
                  SplitType.percentage,
                  SplitType.shares,
                  SplitType.adjustment,
                ];
                final type = splitTypes[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildSplitCard(isDark, type),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitCard(bool isDark, SplitType type) {
    final isSelected = widget.splitType == type;
    final cardData = _getCardData(type);

    return Semantics(
      button: true,
      label: '${cardData.label} split${isSelected ? ' - selected' : ''}',
      onTap: () => widget.onSplitTypeChanged(type),
      child: GestureDetector(
        onTap: () => widget.onSplitTypeChanged(type),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brand
                : AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.brand
                  : AppColors.brand.withValues(alpha: 0.3),
              width: isSelected ? 0 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                cardData.icon,
                size: 28,
                color: isSelected
                    ? Colors.white
                    : AppColors.brand,
              ),
              const SizedBox(height: 8),
              Text(
                cardData.label,
                style: AppTextStyles.caption(isDark).copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : AppColors.textPrimary(isDark),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                cardData.description,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: isSelected
                      ? Colors.white70
                      : AppColors.textSecondary(isDark),
                  fontSize: 10,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SplitCardData _getCardData(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return _SplitCardData(
          icon: Icons.people_outline,
          label: 'Equally',
          description: 'Same share',
        );
      case SplitType.exact:
        return _SplitCardData(
          icon: Icons.attach_money_rounded,
          label: 'Exact',
          description: 'Amount each',
        );
      case SplitType.percentage:
        return _SplitCardData(
          icon: Icons.percent,
          label: 'By %',
          description: 'Percent each',
        );
      case SplitType.shares:
        return _SplitCardData(
          icon: Icons.pie_chart_outline,
          label: 'By Shares',
          description: 'Weight-based',
        );
      case SplitType.adjustment:
        return _SplitCardData(
          icon: Icons.tune,
          label: 'Adjustment',
          description: 'Equal + offset',
        );
    }
  }
}

class _SplitCardData {
  final IconData icon;
  final String label;
  final String description;

  _SplitCardData({
    required this.icon,
    required this.label,
    required this.description,
  });
}
