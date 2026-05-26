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
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(apiClientProvider));
});
