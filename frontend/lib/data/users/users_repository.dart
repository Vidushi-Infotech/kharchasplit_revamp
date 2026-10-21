import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../modules/groups/state/registered_users_provider.dart';

class UsersApiException implements Exception {
  UsersApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Result returned by the privacy-trimmed phone lookup. `null` from the
/// repository means "no user found"; a `PhoneLookupResult` means a hit,
/// with `isSelf` flagging that the caller searched their own number.
class PhoneLookupResult {
  PhoneLookupResult({
    required this.id,
    required this.name,
    required this.phoneSuffix,
    required this.isSelf,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  /// Last 4 digits of the user's phone — used only for visual confirmation
  /// ("did I type the right number?") since the caller already knows the
  /// full number they searched.
  final String phoneSuffix;
  final bool isSelf;
}

class UsersRepository {
  UsersRepository(this._client);
  final ApiClient _client;

  /// Returns the set of phone numbers (in the **normalized** 10-digit form)
  /// that the backend already has registered users for.
  ///
  /// The backend accepts arbitrary phone formats; we normalize the response
  /// so the contacts UI can match against device-contact numbers directly.
  Future<Set<String>> checkRegistration(List<String> phoneNumbers) async {
    if (phoneNumbers.isEmpty) return const {};
    final res = await _client.dio.post(
      '/users/check-registration',
      data: {'phoneNumbers': phoneNumbers},
    );
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw UsersApiException(msg, statusCode: res.statusCode);
    }
    final data = body['data'];
    if (data is! Map) return const {};
    final registered = data['registered'];
    if (registered is! List) return const {};
    return registered
        .whereType<Map>()
        .map((r) => r['phoneNumber']?.toString() ?? '')
        .where((p) => p.isNotEmpty)
        .map(normalizePhone)
        .toSet();
  }

  /// Privacy-trimmed lookup for the "Add member by phone" search box.
  ///
  /// Returns:
  /// * `PhoneLookupResult` — number matches a registered user. `isSelf` is
  ///   true when the caller searched their own number.
  /// * `null` — 404 from server, i.e. no registered user with that number.
  /// * Throws `UsersApiException(statusCode: 429)` when the per-user rate
  ///   limit is hit (30/hour). The UI should display a "try later" hint.
  /// * Throws `UsersApiException` for other transport/server errors.
  Future<PhoneLookupResult?> lookupByPhone(String phone) async {
    try {
      final res = await _client.dio.get(
        '/users/lookup-by-phone',
        queryParameters: {'phone': phone},
      );
      // 4xx arrive as responses (client validateStatus < 500), so the
      // "no such user" 404 must be handled here — the DioException branch
      // below only ever sees 5xx / transport errors.
      if (res.statusCode == 404) return null;
      final body = res.data;
      if (body is! Map || body['success'] != true) {
        final msg = (body is Map ? body['error'] : null)?.toString() ??
            'Request failed (status ${res.statusCode})';
        throw UsersApiException(msg, statusCode: res.statusCode);
      }
      final data = body['data'];
      if (data is! Map) return null;
      return PhoneLookupResult(
        id: (data['id'] ?? '').toString(),
        name: (data['name'] ?? '').toString(),
        avatarUrl: data['avatarUrl']?.toString(),
        phoneSuffix: (data['phoneSuffix'] ?? '').toString(),
        isSelf: data['isSelf'] == true,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) return null;
      final body = e.response?.data;
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          e.message ??
          'Lookup failed';
      throw UsersApiException(msg, statusCode: status);
    }
  }
}

/// Optional email verification (Profile → "Not verified · Verify").
extension EmailVerificationApi on UsersRepository {
  /// Asks the backend to email a code to the user's own address. Throws
  /// [UsersApiException] with `statusCode == 429` on the resend cooldown.
  Future<void> requestEmailVerification(String userId) async {
    final res =
        await _client.dio.post('/users/$userId/email/verify/request');
    _ensureEnvelope(res);
  }

  /// Confirms the code. Returns the updated user payload (carries
  /// `emailVerifiedAt`) so the caller can refresh auth state.
  Future<Map<String, dynamic>> confirmEmailVerification(
    String userId,
    String otp,
  ) async {
    final res = await _client.dio.post(
      '/users/$userId/email/verify/confirm',
      data: {'otp': otp},
    );
    final body = _ensureEnvelope(res);
    final data = body['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  Map<String, dynamic> _ensureEnvelope(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw UsersApiException(msg, statusCode: res.statusCode);
    }
    return body.cast<String, dynamic>();
  }
}

/// What the payer needs to pay someone by UPI (GET /users/:id/payment-info).
class PaymentInfo {
  const PaymentInfo({
    required this.userId,
    required this.name,
    required this.hasUpiId,
    required this.upiId,
    required this.owedAmount,
  });

  final String userId;
  final String name;
  final bool hasUpiId;

  /// Only sent while the caller owes this person money in a shared group —
  /// VPAs often contain phone numbers, so the server withholds it otherwise.
  final String? upiId;
  final double owedAmount;

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    final upi = json['upiId']?.toString().trim();
    return PaymentInfo(
      userId: (json['userId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      hasUpiId: json['hasUpiId'] == true,
      upiId: upi == null || upi.isEmpty ? null : upi,
      owedAmount: (json['owedAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// UPI ID on the profile + pay-by-UPI lookups (feature flag `upiPay`).
extension UpiApi on UsersRepository {
  /// Sets (or with null / "" clears) the caller's own UPI ID. The server
  /// trims, lowercases and validates; a 400 surfaces as [UsersApiException]
  /// carrying the server's message.
  Future<void> updateUpiId(String userId, String? upiId) async {
    final res = await _client.dio.put(
      '/users/$userId',
      data: {'upiId': (upiId == null || upiId.isEmpty) ? null : upiId},
    );
    _ensureEnvelope(res);
  }

  Future<PaymentInfo> fetchPaymentInfo(String userId) async {
    final res = await _client.dio.get('/users/$userId/payment-info');
    final data = _ensureEnvelope(res)['data'];
    if (data is! Map) {
      throw UsersApiException('Malformed response — expected object');
    }
    return PaymentInfo.fromJson(data.cast<String, dynamic>());
  }

  /// Pushes "please add your UPI ID" to [userId]. Throws with the server's
  /// wording on 409 (already has one), 429 (asked in the last 24h) and 400
  /// (caller doesn't owe them).
  Future<void> requestUpiId(String userId) async {
    final res = await _client.dio.post('/users/$userId/upi-request');
    _ensureEnvelope(res);
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(apiClientProvider));
});
