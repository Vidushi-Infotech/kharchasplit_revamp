import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App theme mode - system, light, or dark
enum AppThemeMode { system, light, dark }

/// Riverpod provider for theme mode state (Riverpod 3.x)
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(
      ThemeModeNotifier.new,
    );

/// State notifier for managing theme mode
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _loadSavedTheme();
    return AppThemeMode.system;
  }

  /// Load saved theme preference from shared_preferences
  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('app_theme_mode') ?? 'system';
      state = AppThemeMode.values.firstWhere(
        (e) => e.toString().split('.').last == saved,
        orElse: () => AppThemeMode.system,
      );
    } catch (e) {
      state = AppThemeMode.system;
    }
  }

  /// Change theme mode and save to shared_preferences
  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', mode.toString().split('.').last);
    } catch (e) {
      // Silently fail - theme will still change in-app
    }
  }

  /// Convert AppThemeMode to Flutter's ThemeMode
  ThemeMode toThemeMode() => switch (state) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}

/// Helper to check if dark mode is active
extension ThemeHelper on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
