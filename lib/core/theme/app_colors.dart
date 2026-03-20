import 'package:flutter/material.dart';

/// Centralized color system with dual dark/light tokens
/// All colors accessed via helper methods — never hardcoded in widgets
class AppColors {
  // ── Brand Colors (constant across both themes) ──────────────────────────
  static const Color tealDark = Color(0xFF1A7A6E);
  static const Color tealLight = Color(0xFF00897B);
  static const Color greenLight = Color(0xFF8DC98A);
  static const Color orange = Color(0xFFF4872A);
  static const Color gray = Color(0xFFB0B0B0);

  // ── Dark Theme Color Tokens ───────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0D1F1D);
  static const Color darkSurface = Color(0xFF162B28);
  static const Color darkCardBg = Color(0xFF1E3632);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0C4C2);
  static const Color darkDivider = Color(0xFF2A4440);
  static const Color darkInputFill = Color(0xFF1E3632);
  static const Color darkInputBorder = Color(0xFF2A4440);
  static const Color darkErrorBg = Color(0xFF3D2522);
  static const Color darkErrorText = Color(0xFFFF8B7B);

  // ── Light Theme Color Tokens ──────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF0F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0D1F1D);
  static const Color lightTextSecondary = Color(0xFF4A6B68);
  static const Color lightDivider = Color(0xFFDDECEA);
  static const Color lightInputFill = Color(0xFFF5FAF9);
  static const Color lightInputBorder = Color(0xFFB0D4D0);
  static const Color lightErrorBg = Color(0xFFFBE4E1);
  static const Color lightErrorText = Color(0xFFD32F2F);

  // ── Helper Methods (use these EVERYWHERE in widgets) ──────────────────────

  /// Background color - used for Scaffold.backgroundColor
  static Color background(bool isDark) =>
      isDark ? darkBackground : lightBackground;

  /// Primary surface - cards, sheets, dialogs
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;

  /// Card background - same as surface but for explicit cards
  static Color cardBg(bool isDark) => isDark ? darkCardBg : lightCardBg;

  /// Primary text - headings, labels, important content
  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;

  /// Secondary text - hints, descriptions, meta
  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;

  /// Input field fill color
  static Color inputFill(bool isDark) =>
      isDark ? darkInputFill : lightInputFill;

  /// Input field border color
  static Color inputBorder(bool isDark) =>
      isDark ? darkInputBorder : lightInputBorder;

  /// Divider and border lines
  static Color divider(bool isDark) => isDark ? darkDivider : lightDivider;

  /// Error background (filled error state)
  static Color errorBg(bool isDark) => isDark ? darkErrorBg : lightErrorBg;

  /// Error text and icons
  static Color errorText(bool isDark) => isDark ? darkErrorText : lightErrorText;

  /// Brand primary (both themes use teal)
  static const Color brand = tealDark;

  /// Success (positive balance, money received)
  static const Color success = greenLight;

  /// Warning (pending, attention needed)
  static const Color warning = orange;
}
