import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory security preferences. Future work: persist locally with secure
/// storage / Hive and sync sensitive parts (sessions, 2FA) to the backend.
class SecurityPrefs {
  const SecurityPrefs({
    this.biometricUnlock = false,
    this.appLockPin = false,
    this.hideAmountsOnBackground = false,
    this.twoFactor = false,
  });

  final bool biometricUnlock;
  final bool appLockPin;
  final bool hideAmountsOnBackground;
  final bool twoFactor;

  SecurityPrefs copyWith({
    bool? biometricUnlock,
    bool? appLockPin,
    bool? hideAmountsOnBackground,
    bool? twoFactor,
  }) {
    return SecurityPrefs(
      biometricUnlock: biometricUnlock ?? this.biometricUnlock,
      appLockPin: appLockPin ?? this.appLockPin,
      hideAmountsOnBackground:
          hideAmountsOnBackground ?? this.hideAmountsOnBackground,
      twoFactor: twoFactor ?? this.twoFactor,
    );
  }
}

class SecurityPrefsNotifier extends Notifier<SecurityPrefs> {
  @override
  SecurityPrefs build() => const SecurityPrefs();

  void update(SecurityPrefs Function(SecurityPrefs) mutator) {
    state = mutator(state);
  }
}

final securityPrefsProvider =
    NotifierProvider<SecurityPrefsNotifier, SecurityPrefs>(
  SecurityPrefsNotifier.new,
);
