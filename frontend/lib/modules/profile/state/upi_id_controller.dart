import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/users/users_repository.dart';
import '../../auth/state/auth_provider.dart';

/// Same rule the server applies (after trim + lowercase): `handle@psp`.
final _upiIdPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{1,255}@[a-z][a-z0-9]{1,63}$');

/// Trimmed + lowercased form, as the server stores it.
String normalizeUpiId(String raw) => raw.trim().toLowerCase();

/// Empty is valid (it clears the UPI ID).
bool isValidUpiId(String raw) {
  final v = normalizeUpiId(raw);
  return v.isEmpty || _upiIdPattern.hasMatch(v);
}

/// Saves the signed-in user's UPI ID and pulls the fresh profile into
/// [authProvider] so every screen sees it.
class UpiIdController {
  UpiIdController(this._ref);
  final Ref _ref;

  /// [raw] empty clears it. Throws [UsersApiException] with the server's
  /// wording (e.g. invalid format) on failure.
  Future<void> save(String raw) async {
    final user = _ref.read(authProvider).user;
    if (user == null) throw UsersApiException('Not signed in');
    final value = normalizeUpiId(raw);
    await _ref
        .read(usersRepositoryProvider)
        .updateUpiId(user.id, value.isEmpty ? null : value);
    await _ref.read(authProvider.notifier).refreshProfile();
  }
}

final upiIdControllerProvider = Provider<UpiIdController>(
  UpiIdController.new,
);
