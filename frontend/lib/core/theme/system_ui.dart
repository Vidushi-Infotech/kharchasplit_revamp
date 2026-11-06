import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar and Android navigation bar styles, in one place.
///
/// Both bars are transparent (the app draws edge to edge) and their icons
/// follow what's behind them: dark icons on light pages, light icons on
/// dark pages and on the teal banners. Flutter's ready-made
/// `SystemUiOverlayStyle.light` / `.dark` also paint Android's navigation
/// bar black, so screens use these instead.
///
/// iOS reads `statusBarBrightness` (the brightness of what's *behind* the
/// bar); Android reads the `…IconBrightness` fields.
abstract final class AppSystemUi {
  /// A plain page in the app's light or dark theme.
  static SystemUiOverlayStyle page(bool isDark) => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  /// A dark header (the teal group / friend banner) at the top of a page
  /// in either theme: light status bar icons, navigation bar as the page.
  static SystemUiOverlayStyle overDarkHeader(bool isDark) =>
      page(isDark).copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      );

  /// A screen that is always dark (photo crop, full-screen receipt,
  /// onboarding).
  static SystemUiOverlayStyle alwaysDark() => page(true);
}
