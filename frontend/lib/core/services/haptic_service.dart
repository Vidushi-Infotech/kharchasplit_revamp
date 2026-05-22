import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Semantic intensities. Call sites name *intent* (tap / success / error),
/// not the underlying Flutter API. Lets us swap to a richer library later
/// (e.g. `gaptic_feedback` for iOS-native success/warning/error) without
/// touching every widget.
enum HapticIntensity { selection, light, medium, heavy }

/// Process-wide haptic feedback service.
///
/// Singleton so widgets that don't have Riverpod `ref` (e.g. the central
/// [PrimaryButton] and [CustomBottomNavigationBar]) can call it directly:
///   `HapticService.instance.tap();`
///
/// The Riverpod-backed `hapticEnabledProvider` writes through to
/// [setEnabled] whenever the user flips the master toggle, so this
/// service is always in sync with the persisted preference.
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  // Default ON. Overwritten on app start once the persisted pref loads.
  bool _enabled = true;

  // Per-intensity timestamp of the last successful fire. Used to collapse
  // rapid repeats (e.g. user mashing a button) into a single haptic.
  final Map<HapticIntensity, int> _lastFiredMs = {};

  /// Minimum gap between two haptics of the same intensity.
  /// 80 ms is short enough to feel "every tap" but long enough to
  /// prevent buzz-storms on double-taps.
  static const int _throttleMs = 80;

  bool get isEnabled => _enabled;
  void setEnabled(bool v) => _enabled = v;

  // ---------------------------------------------------------------
  // Semantic API — prefer these. See HAPTICS_PLAN.md §4 for mapping.
  // ---------------------------------------------------------------

  /// Most button taps, nav rows, IconButton presses. Subtle.
  void tap() => _fire(HapticIntensity.light);

  /// Crossing a discrete boundary — toggle flip, segment change,
  /// bottom-nav tab change, picker reel, category chip selection.
  void selection() => _fire(HapticIntensity.selection);

  /// Successful submit / important confirmation.
  /// (Expense added, settlement created, OTP verified.)
  void success() => _fire(HapticIntensity.medium);

  /// Threshold crossed during a continuous gesture —
  /// pull-to-refresh release point, Dismissible commit threshold,
  /// long-press engaged.
  void thresholdCrossed() => _fire(HapticIntensity.medium);

  /// Validation / business-rule rejection (4xx).
  void error() => _fire(HapticIntensity.heavy);

  /// User confirmed a destructive action (Delete, Sign out everywhere).
  void destructive() => _fire(HapticIntensity.heavy);

  /// Escape hatch when a call site really needs raw intensity control.
  void custom(HapticIntensity intensity) => _fire(intensity);

  // ---------------------------------------------------------------

  void _fire(HapticIntensity intensity) {
    if (!_enabled) return;
    // Web has no haptic motor; calling the API would still no-op but
    // the early return saves a channel call.
    if (kIsWeb) return;
    if (!_throttleOk(intensity)) return;

    switch (intensity) {
      case HapticIntensity.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticIntensity.light:
        HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }

  bool _throttleOk(HapticIntensity intensity) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastFiredMs[intensity] ?? 0;
    if (now - last < _throttleMs) return false;
    _lastFiredMs[intensity] = now;
    return true;
  }
}
