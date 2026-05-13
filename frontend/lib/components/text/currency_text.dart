import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';

/// Widget for displaying formatted currency amounts
/// Automatically applies color based on positive/negative
class CurrencyText extends StatelessWidget {
  final double amount;
  final String currency;
  final TextStyle? textStyle;
  final bool showSign;
  final int decimalPlaces;
  final bool animated;
  final Duration animationDuration;
  final Color? overrideColor;

  const CurrencyText(
    this.amount, {
    Key? key,
    this.currency = '₹',
    this.textStyle,
    this.showSign = false,
    this.decimalPlaces = 2,
    this.animated = false,
    this.animationDuration = const Duration(milliseconds: 500),
    this.overrideColor,
  }) : super(key: key);

  Color _getColor(bool isDark) {
    if (overrideColor != null) return overrideColor!;

    if (amount > 0) {
      return AppColors.greenLight;
    } else if (amount < 0) {
      return AppColors.warningOrange;
    }
    return AppColors.textSecondary(isDark);
  }

  String _formatAmount() {
    return CurrencyFormatter.format(
      amount,
      currency: currency,
      showSign: showSign,
      decimalPlaces: decimalPlaces,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getColor(isDark);

    if (animated) {
      return _buildAnimatedText(context, color);
    }

    return Text(
      _formatAmount(),
      style: (textStyle ?? AppTextStyles.body1(isDark)).copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAnimatedText(BuildContext context, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: amount - 1, end: amount),
      duration: animationDuration,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Text(
          CurrencyFormatter.format(
            value,
            currency: currency,
            showSign: showSign,
            decimalPlaces: decimalPlaces,
          ),
          style: (textStyle ?? AppTextStyles.body1(isDark)).copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

/// Compact currency display for cards and tiles
class CompactCurrencyText extends StatelessWidget {
  final double amount;
  final String currency;
  final TextStyle? textStyle;

  const CompactCurrencyText(
    this.amount, {
    Key? key,
    this.currency = '₹',
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = amount > 0 ? AppColors.greenLight : AppColors.warningOrange;

    return Text(
      CurrencyFormatter.compact(amount, currency: currency),
      style: (textStyle ?? AppTextStyles.body2(isDark)).copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
