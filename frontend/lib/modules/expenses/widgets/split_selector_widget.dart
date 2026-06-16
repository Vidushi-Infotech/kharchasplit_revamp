import 'package:flutter/material.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

/// Compact 2x2 grid of split-type options. Picks the same 4 SplitTypes
/// as before — only the visual styling changed to match the rest of the
/// redesigned screens (hairline borders, subtle tints, no brand-color fills).
class SplitSelectorWidget extends StatelessWidget {
  const SplitSelectorWidget({
    super.key,
    required this.splitType,
    required this.amount,
    required this.onSplitTypeChanged,
  });

  final SplitType splitType;
  final double amount;
  final ValueChanged<SplitType> onSplitTypeChanged;

  static const _options = <_OptionData>[
    _OptionData(
      type: SplitType.equal,
      icon: Icons.balance_rounded,
      label: 'Equally',
      description: 'Same share',
    ),
    _OptionData(
      type: SplitType.exact,
      icon: Icons.tune_rounded,
      label: 'Unequally',
      description: 'Amount each',
    ),
    _OptionData(
      type: SplitType.percentage,
      icon: Icons.percent_rounded,
      label: 'By %',
      description: 'Percent each',
    ),
    _OptionData(
      type: SplitType.shares,
      icon: Icons.pie_chart_outline_rounded,
      label: 'By shares',
      description: 'Weight-based',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOW TO SPLIT',
          style: AppTextStyles.caption(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            // 2-column grid; on very narrow screens fall back to a single column.
            final crossAxisCount = constraints.maxWidth < 320 ? 1 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: crossAxisCount == 1 ? 4.6 : 2.6,
              children: [
                for (final opt in _options)
                  _OptionCard(
                    isDark: isDark,
                    data: opt,
                    selected: splitType == opt.type,
                    onTap: () {
                      if (splitType != opt.type) {
                        HapticService.instance.selection();
                        onSplitTypeChanged(opt.type);
                      }
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.isDark,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final bool isDark;
  final _OptionData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.tealDark;
    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
        : AppColors.cardBg(isDark);
    final borderColor = selected
        ? accent.withValues(alpha: 0.55)
        : AppColors.divider(isDark);
    final textColor = selected ? accent : AppColors.textPrimary(isDark);

    return Semantics(
      button: true,
      label: '${data.label} split${selected ? ', selected' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: selected ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    data.icon,
                    size: 17,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.label,
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.description,
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 11,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionData {
  const _OptionData({
    required this.type,
    required this.icon,
    required this.label,
    required this.description,
  });

  final SplitType type;
  final IconData icon;
  final String label;
  final String description;
}
