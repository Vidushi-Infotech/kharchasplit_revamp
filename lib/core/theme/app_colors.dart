import 'package:flutter/material.dart';

/// Centralized color system with dual dark/light tokens
/// All colors accessed via helper methods — never hardcoded in widgets
class AppColors {
  // ── Brand Colors (constant across both themes) ──────────────────────────
  static const Color tealDark = Color(0xFF1A7A6E);
  static const Color tealLight = Color(0xFF00897B);
  static const Color greenLight = Color(0xFF8DC98A);
  static const Color orange = Color(0xFFF4872A);
  static const Color warningOrange = Color(0xFFF4872A);
  static const Color gray = Color(0xFFB0B0B0);
  static const Color greyLight = Color(0xFFE0E0E0);

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

  /// Success light background (for success badges/alerts)
  static Color successLight(bool isDark) =>
      isDark ? const Color(0xFF1B5E20).withOpacity(0.2) : const Color(0xFFE8F5E9);

  /// Warning light background (for warning badges/alerts)
  static Color warningLight(bool isDark) =>
      isDark ? const Color(0xFFFFF3E0).withOpacity(0.2) : const Color(0xFFFFF3E0);

  // ── Avatar Color Palette (for consistent user avatar backgrounds) ──────────────
  /// List of avatar background colors for consistent coloring by user name hash
  static const List<Color> avatarColors = [
    Color(0xFFEF5350), // Red
    Color(0xFFEC407A), // Pink
    Color(0xFFAB47BC), // Purple
    Color(0xFF7E57C2), // Deep Purple
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF42A5F5), // Blue
    Color(0xFF29B6F6), // Cyan
    Color(0xFF26C6DA), // Teal
    Color(0xFF66BB6A), // Green
    Color(0xFF9CCC65), // Lime
    Color(0xFFFFCA28), // Amber
    Color(0xFFFF7043), // Orange
  ];

  /// Online status indicator color
  static const Color online = Color(0xFF4CAF50);

  /// Offline status indicator color
  static Color offline(bool isDark) =>
      isDark ? const Color(0xFF616161) : const Color(0xFFBDBDBD);

  /// Unread indicator color (for activity, notifications, etc.)
  static const Color unread = Color(0xFF2196F3);

  // ── Social Platform Colors (for authentication buttons) ──────────────────────
  /// Google brand color
  static const Color googleBrand = Color(0xFF4285F4);

  /// Facebook brand color
  static const Color facebookBrand = Color(0xFF1877F2);
}
