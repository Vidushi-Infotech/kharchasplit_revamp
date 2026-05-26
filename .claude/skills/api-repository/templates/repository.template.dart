// Template: frontend/lib/data/<resource>/<resource>_repository.dart
//
// Drop into a new file under frontend/lib/data/<resource>/.
// Replace placeholders: <Resource>, <resource>, <Model>.
// Mirrors the structure of frontend/lib/data/expenses/expenses_repository.dart.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/<resource>_model.dart';

class <Resource>ApiException implements Exception {
  <Resource>ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class <Resource>Repository {
  <Resource>Repository(this._client);
  final ApiClient _client;

  // -------- GET list --------

  Future<List<<Resource>Model>> listForGroup(
    String groupId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.dio.get(
      '/<resource>s',
      queryParameters: {
        'groupId': groupId,
        'page': page,
        'limit': limit,
      },
    );
    final data = _ensureList(res);
    return data
        .whereType<Map<String, dynamic>>()
        .map(<Resource>Model.fromJson)
        .toList();
  }

  // -------- GET one --------

  Future<<Resource>Model> getById(String id) async {
    final res = await _client.dio.get('/<resource>s/$id');
    return <Resource>Model.fromJson(_ensureMap(res));
  }

  // -------- POST create --------

  Future<<Resource>Model> create({
    required String groupId,
    // required <typed field>,
    // String? currency,
  }) async {
    final res = await _client.dio.post(
      '/<resource>s',
      data: {
        'groupId': groupId,
        // 'field': field,
        // if (currency != null) 'currency': _normalizeCurrency(currency),
      },
    );
    return <Resource>Model.fromJson(_ensureMap(res));
  }

  // -------- PUT update --------

  Future<<Resource>Model> update(
    String id, {
    // String? field,
  }) async {
    final res = await _client.dio.put(
      '/<resource>s/$id',
      data: {
        // if (field != null) 'field': field,
      },
    );
    return <Resource>Model.fromJson(_ensureMap(res));
  }

  // -------- DELETE --------

  Future<void> delete(String id) async {
    final res = await _client.dio.delete('/<resource>s/$id');
    _ensureSuccess(res);
  }

  // -------- helpers (do not modify) --------

  String _normalizeCurrency(String input) {
    switch (input) {
      case '₹':
        return 'INR';
      case '\$':
        return 'USD';
      case '€':
        return 'EUR';
      case '£':
        return 'GBP';
      default:
        return input.length == 3 ? input.toUpperCase() : 'INR';
    }
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw <Resource>ApiException(msg, statusCode: res.statusCode);
    }
    return body.cast<String, dynamic>();
  }

  Map<String, dynamic> _ensureMap(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw <Resource>ApiException('Malformed response — expected object in data');
    }
    return data;
  }

  List<dynamic> _ensureList(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! List) {
      throw <Resource>ApiException('Malformed response — expected list in data');
    }
    return data;
  }
}

final <resource>RepositoryProvider = Provider<<Resource>Repository>((ref) {
  return <Resource>Repository(ref.watch(apiClientProvider));
});
