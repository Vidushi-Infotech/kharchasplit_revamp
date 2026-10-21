import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/users/users_repository.dart';

/// Payee's UPI details for the Record payment screen, keyed by user id.
/// Auto-disposed so a freshly added UPI ID shows up next time the screen
/// opens.
final paymentInfoProvider = FutureProvider.autoDispose
    .family<PaymentInfo, String>((ref, userId) {
      return ref.read(usersRepositoryProvider).fetchPaymentInfo(userId);
    });

/// Actions around the payee's UPI ID.
class UpiRequestController {
  UpiRequestController(this._ref);
  final Ref _ref;

  /// Asks [userId] to add a UPI ID. Throws [UsersApiException] carrying
  /// the server's wording (already has one / asked recently / not owed).
  Future<void> askForUpiId(String userId) =>
      _ref.read(usersRepositoryProvider).requestUpiId(userId);
}

final upiRequestControllerProvider = Provider<UpiRequestController>(
  UpiRequestController.new,
);
