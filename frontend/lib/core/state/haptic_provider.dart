import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/haptic_service.dart';

/// User-controlled master toggle for haptic feedback. Persisted locally
/// via [SharedPreferences] (device-level, not synced to backend — same
/// pattern as the theme preference).
///
/// Default: ON. Loaded asynchronously on first read; the [HapticService]
/// singleton is always kept in sync via [HapticEnabledNotifier.setEnabled].
final hapticEnabledProvider =
    NotifierProvider<HapticEnabledNotifier, bool>(HapticEnabledNotifier.new);

class HapticEnabledNotifier extends Notifier<bool> {
  static const _prefsKey = 'pref.haptics_enabled';

  @override
  bool build() {
    // Fire-and-forget load. The initial `true` is correct for the common
    // case (haptics default ON); if the user has disabled them previously,
    // the toggle will flip a frame later — invisible in practice.
    _load();
    HapticService.instance.setEnabled(true);
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_prefsKey) ?? true;
      if (state != v) state = v;
      HapticService.instance.setEnabled(v);
    } catch (_) {
      // SharedPreferences read failure is non-fatal — keep the default.
    }
  }

  /// Flip the master toggle. Gives a small audible nod so the user
  /// knows the change took effect: a `selection` click on the way OFF
  /// (the goodbye), a `success` thump on the way back ON (welcome).
  /// These fire BEFORE we mutate state so the service is still enabled
  /// for the goodbye click.
  Future<void> setEnabled(bool v) async {
    if (v == state) return;

    if (state && !v) {
      // OFF transition — last click while still enabled.
      HapticService.instance.selection();
    }

    state = v;
    HapticService.instance.setEnabled(v);

    if (v) {
      // ON transition — welcome thump.
      HapticService.instance.success();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, v);
    } catch (_) {
      // Write failure is non-fatal; in-memory state still reflects the choice.
    }
  }
}
