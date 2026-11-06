import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/add_expense_split_math.dart';

/// The five split methods as a row of icon tabs (Splitwise style):
/// `=` equally, `1.23` exact amounts, `%` percentages, shares (bars) and
/// `+/−` adjustment. The selected tab is filled with the brand color.
class SplitSelectorWidget extends StatelessWidget {
  const SplitSelectorWidget({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final AddExpenseSplitMode mode;
  final ValueChanged<AddExpenseSplitMode> onModeChanged;

  static const _tabs = <_TabData>[
    _TabData(AddExpenseSplitMode.equal, '=', AppStrings.splitTabEqually),
    _TabData(AddExpenseSplitMode.exact, '1.23', AppStrings.splitTabExact),
    _TabData(AddExpenseSplitMode.percentage, '%', AppStrings.splitTabPercent),
    _TabData(AddExpenseSplitMode.shares, null, AppStrings.splitTabShares),
    _TabData(AddExpenseSplitMode.adjustment, '+/−', AppStrings.splitTabAdjust),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        for (final t in _tabs)
          Expanded(
            child: _Tab(
              data: t,
              isDark: isDark,
              selected: t.mode == mode,
              onTap: () {
                if (t.mode == mode) return;
                HapticService.instance.selection();
                onModeChanged(t.mode);
              },
            ),
          ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.data,
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  final _TabData data;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary(isDark);
    final glyph = data.glyph;
    return Semantics(
      button: true,
      selected: selected,
      label: '${data.label} split',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.tealDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppColors.tealDark
                        : AppColors.divider(isDark),
                  ),
                ),
                child: glyph == null
                    ? Icon(Icons.bar_chart_rounded, size: 22, color: fg)
                    : Text(
                        glyph,
                        maxLines: 1,
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: glyph.length > 2 ? 14 : 20,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: selected
                      ? AppColors.tealDark
                      : AppColors.textSecondary(isDark),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData(this.mode, this.glyph, this.label);

  final AddExpenseSplitMode mode;

  /// Text drawn in the tab; null = the shares bar icon.
  final String? glyph;
  final String label;
}
