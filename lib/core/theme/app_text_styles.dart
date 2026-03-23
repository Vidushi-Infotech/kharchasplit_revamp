import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Responsive, theme-aware text styles
/// Use with Theme.of(context) to get isDark boolean
class AppTextStyles {
  static TextStyle _baseStyle(bool isDark, double fontSize) {
    return TextStyle(
      fontFamily: 'Roboto',
      fontSize: fontSize,
      color: AppColors.textPrimary(isDark),
      height: 1.5,
    );
  }

  // ── Headings ──────────────────────────────────────────────────────────────
  static TextStyle headline1(bool isDark) =>
      _baseStyle(isDark, 32).copyWith(fontWeight: FontWeight.bold);

  static TextStyle headline2(bool isDark) =>
      _baseStyle(isDark, 28).copyWith(fontWeight: FontWeight.bold);

  static TextStyle headline3(bool isDark) =>
      _baseStyle(isDark, 24).copyWith(fontWeight: FontWeight.w700);

  // ── Body & Descriptions ───────────────────────────────────────────────────
  static TextStyle body1(bool isDark) =>
      _baseStyle(isDark, 16).copyWith(fontWeight: FontWeight.w500);

  static TextStyle body2(bool isDark) => _baseStyle(isDark, 14);

  static TextStyle caption(bool isDark) =>
      _baseStyle(isDark, 12).copyWith(color: AppColors.textSecondary(isDark));

  static TextStyle button(bool isDark) => _baseStyle(isDark, 16).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  // ── Error Text ────────────────────────────────────────────────────────────
  static TextStyle error(bool isDark) =>
      _baseStyle(isDark, 12).copyWith(color: AppColors.errorText(isDark));

  // ── Success/Hint ──────────────────────────────────────────────────────────
  static TextStyle hint(bool isDark) =>
      _baseStyle(isDark, 14).copyWith(color: AppColors.textSecondary(isDark));
}
