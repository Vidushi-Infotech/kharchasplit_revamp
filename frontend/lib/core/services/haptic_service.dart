import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

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
///
/// Platform routing:
/// - **Android:** uses the `vibration` package (`Vibrator.vibrate(...)`).
///   We cannot use Flutter's `HapticFeedback.lightImpact` etc. on Android
///   because most Samsung devices gate `View.performHapticFeedback()`
///   behind a per-feature "Touch feedback" system toggle that's OFF by
///   default — the call silently no-ops even with VIBRATE permission.
///   `vibration` talks to the VibratorManager service directly with a
///   duration + amplitude pair, bypassing that gate.
/// - **iOS:** uses the native `HapticFeedback.*` API. iOS exposes proper
///   `UIImpactFeedbackGenerator` patterns via these calls and they work
///   reliably on physical devices (simulator has no haptic motor).
/// - **Web / desktop:** no-op.
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  // Default ON. Overwritten on app start once the persisted pref loads.
  bool _enabled = true;

  /// Whether the device actually has a vibration motor. Resolved lazily
  /// on first fire to avoid blocking app startup.
  bool? _hasVibrator;

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

  Future<void> _fire(HapticIntensity intensity) async {
    if (!_enabled) return;
    if (kIsWeb) return;
    if (!_throttleOk(intensity)) return;

    if (Platform.isIOS) {
      // iOS — native UIImpactFeedbackGenerator path via Flutter's API.
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
      return;
    }

    if (Platform.isAndroid) {
      // Cache the hardware check so we don't ping the channel per tap.
      _hasVibrator ??= (await Vibration.hasVibrator()) == true;
      if (_hasVibrator != true) return;

      // Duration + amplitude tuned for Samsung devices specifically —
      // their haptic motor needs stronger pulses than the iOS-equivalent
      // values to be perceptible through a typical case + finger pressure.
      // Amplitudes are 1..255; durations capped so the cue still reads
      // as a haptic tap, not a phone-call notification buzz.
      final int duration;
      final int amplitude;
      switch (intensity) {
        case HapticIntensity.selection:
          duration = 20;
          amplitude = 140;
          break;
        case HapticIntensity.light:
          duration = 35;
          amplitude = 180;
          break;
        case HapticIntensity.medium:
          duration = 55;
          amplitude = 220;
          break;
        case HapticIntensity.heavy:
          duration = 90;
          amplitude = 255;
          break;
      }
      // Amplitude control requires API 26+ on Android — older devices
      // ignore the value and fall back to a default vibration. Safe.
      Vibration.vibrate(duration: duration, amplitude: amplitude);
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
