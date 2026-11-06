import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/personal_transfer_model.dart';
import '../../models/wallet_source_model.dart';

/// Personal mode accounts and transfers: /personal-accounts. Balances come
/// back computed by the server.
class PersonalAccountsRepository {
  PersonalAccountsRepository(this._client);
  final ApiClient _client;

  Future<List<WalletSource>> list() async =>
      _accounts(await _client.dio.get('/personal-accounts'));

  /// Moves the phone-only wallet to the server, once: [links] maps entry
  /// ids to the local source ids in [sources]. The server ignores it when
  /// the user already has accounts. Returns the accounts either way.
  Future<List<WalletSource>> importLocal(
    List<WalletSource> sources,
    Map<String, String> links,
  ) async {
    final res = await _client.dio.post(
      '/personal-accounts/import',
      data: {
        'accounts': [
          for (final s in sources)
            {
              'key': s.id,
              'name': s.name,
              'type': s.type.name,
              'balance': s.balance,
            },
        ],
        'links': links,
      },
    );
    return _accounts(res);
  }

  Future<void> create({
    required String name,
    required WalletSourceType type,
    required double balance,
  }) async {
    _body(
      await _client.dio.post(
        '/personal-accounts',
        data: {'name': name, 'type': type.name, 'balance': balance},
      ),
    );
  }

  Future<void> update(String id, {String? name, double? balance}) async {
    _body(
      await _client.dio.put(
        '/personal-accounts/$id',
        data: {
          if (name != null) 'name': name,
          if (balance != null) 'balance': balance,
        },
      ),
    );
  }

  Future<void> archive(String id) async =>
      _body(await _client.dio.delete('/personal-accounts/$id'));

  Future<List<PersonalTransfer>> transfers({String? accountId}) async {
    final res = await _client.dio.get(
      '/personal-accounts/transfers',
      queryParameters: {if (accountId != null) 'accountId': accountId},
    );
    final data = _body(res)['data'];
    return data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(PersonalTransfer.fromJson)
              .toList()
        : const [];
  }

  Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    _body(
      await _client.dio.post(
        '/personal-accounts/transfers',
        data: {
          'fromAccountId': fromAccountId,
          'toAccountId': toAccountId,
          'amount': amount,
          if (note != null && note.isNotEmpty) 'note': note,
          if (date != null) 'date': date.toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<void> deleteTransfer(String id) async =>
      _body(await _client.dio.delete('/personal-accounts/transfers/$id'));

  List<WalletSource> _accounts(Response res) {
    final data = _body(res)['data'];
    return data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(WalletSource.fromJson)
              .toList()
        : const [];
  }

  Map<String, dynamic> _body(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      throw Exception(
        (body is Map ? body['error'] : null)?.toString() ??
            'Request failed (status ${res.statusCode})',
      );
    }
    return body.cast<String, dynamic>();
  }
}

final personalAccountsRepositoryProvider = Provider<PersonalAccountsRepository>(
  (ref) => PersonalAccountsRepository(ref.watch(apiClientProvider)),
);
