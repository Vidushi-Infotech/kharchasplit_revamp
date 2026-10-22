import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class DefaultCurrencyOption {
  const DefaultCurrencyOption(this.code, this.symbol, this.name);
  final String code;
  final String symbol;
  final String name;
}

/// Default-currency picker for the (hidden) Preferences row.
class DefaultCurrencyPicker {
  DefaultCurrencyPicker._();

  /// Currencies KharchaSplit ships with. Easy to extend later.
  static const List<DefaultCurrencyOption> options = [
    DefaultCurrencyOption('INR', '₹', 'Indian Rupee'),
    DefaultCurrencyOption('USD', '\$', 'US Dollar'),
    DefaultCurrencyOption('EUR', '€', 'Euro'),
    DefaultCurrencyOption('GBP', '£', 'British Pound'),
    DefaultCurrencyOption('AED', 'د.إ', 'UAE Dirham'),
    DefaultCurrencyOption('SGD', 'S\$', 'Singapore Dollar'),
    DefaultCurrencyOption('AUD', 'A\$', 'Australian Dollar'),
    DefaultCurrencyOption('CAD', 'C\$', 'Canadian Dollar'),
    DefaultCurrencyOption('JPY', '¥', 'Japanese Yen'),
  ];

  static String labelFor(String code) {
    final opt = options.firstWhere(
      (o) => o.code == code,
      orElse: () => DefaultCurrencyOption(code, '', code),
    );
    return opt.symbol.isEmpty ? opt.code : '${opt.code} ${opt.symbol}';
  }

  static void show(
    BuildContext context, {
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CurrencyPickerSheet(
        current: current,
        onSelected: (code) {
          Navigator.of(sheetContext).pop();
          onSelected(code);
        },
      ),
    );
  }
}

class _CurrencyPickerSheet extends StatelessWidget {
  const _CurrencyPickerSheet({required this.current, required this.onSelected});

  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Default currency',
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(isDark),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.divider(isDark),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Used as the default for new groups and personal expenses.',
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: DefaultCurrencyPicker.options.length,
                  itemBuilder: (context, index) {
                    final opt = DefaultCurrencyPicker.options[index];
                    final selected = opt.code == current;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CurrencyRow(
                        option: opt,
                        isSelected: selected,
                        isDark: isDark,
                        onTap: () => onSelected(opt.code),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final DefaultCurrencyOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.tealDark.withValues(alpha: 0.10)
                : AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.tealDark.withValues(alpha: 0.40)
                  : AppColors.divider(isDark),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.tealDark.withValues(alpha: 0.18)
                      : AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.divider(isDark).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  option.symbol.isEmpty ? option.code[0] : option.symbol,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isSelected
                        ? AppColors.tealDark
                        : AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.code,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.name,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.tealDark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
