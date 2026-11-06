import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/haptic_service.dart';

/// The two "apps" inside KharchaSplit: splitting with others (groups,
/// friends, activity) and the user's own personal money manager. Each has
/// its own bottom tabs; the last tab switches to the other.
enum AppMode {
  shared,
  personal;

  /// Where this mode opens.
  String get home => switch (this) {
    AppMode.shared => '/home/groups',
    AppMode.personal => '/personal',
  };
}

/// Remembers the mode the app was last in, so it reopens there.
///
/// Read synchronously ([current]) by launch navigation (splash, login), so
/// [load] runs once in main() before the first frame. Storage failures
/// fall back to the shared mode.
abstract final class AppModeStore {
  static const _key = 'app_mode_v1';
  static AppMode _current = AppMode.shared;

  static AppMode get current => _current;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _current = prefs.getString(_key) == AppMode.personal.name
          ? AppMode.personal
          : AppMode.shared;
    } catch (_) {
      _current = AppMode.shared;
    }
  }

  /// Called by each mode's shell when it shows, so a deep link or a
  /// notification that lands in a mode also counts as switching to it.
  static Future<void> remember(AppMode mode) async {
    if (_current == mode) return;
    _current = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}

/// What the next mode switch looks like: where it was tapped (the circle
/// opens from there) and which mode it's going to. Read by the shell
/// pages' transition (layouts/shell/mode_switch_transition.dart).
abstract final class ModeSwitchSignal {
  /// Last tap on a tab bar / rail switch, in global coordinates.
  static Offset? origin;

  static AppMode? _pending;

  /// True once, for the shell of [mode] right after a switch to it.
  static bool take(AppMode mode) {
    if (_pending != mode) return false;
    _pending = null;
    return true;
  }
}

/// Switch to the other "app": go to its home with the mode-switch
/// transition (a circle opening from the switch, see
/// layouts/shell/mode_switch_transition.dart).
void switchAppMode(BuildContext context, AppMode to) {
  HapticService.instance.success();
  AppModeStore.remember(to);
  ModeSwitchSignal._pending = to;
  context.go(to.home);
}
