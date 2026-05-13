import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/settlement_model.dart';

class SettlementsApiException implements Exception {
  SettlementsApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SettlementsRepository {
  SettlementsRepository(this._client);
  final ApiClient _client;

  Future<List<SettlementModel>> listForGroup(
    String groupId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.dio.get(
      '/settlements',
      queryParameters: {
        'groupId': groupId,
        'page': page,
        'limit': limit,
      },
    );
    final data = _ensureList(res);
    return data
        .whereType<Map<String, dynamic>>()
        .map(SettlementModel.fromJson)
        .toList();
  }

  Future<SettlementModel> create({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String currency,
    String? notes,
  }) async {
    final res = await _client.dio.post(
      '/settlements',
      data: {
        'groupId': groupId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': amount,
        'currency': currency,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    final data = _ensureMap(res);
    return SettlementModel.fromJson(data);
  }

  Future<void> confirm(String settlementId) async {
    final res = await _client.dio.patch('/settlements/$settlementId/confirm');
    _ensureSuccess(res);
  }

  Future<void> delete(String settlementId) async {
    final res = await _client.dio.delete('/settlements/$settlementId');
    _ensureSuccess(res);
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw SettlementsApiException(msg, statusCode: res.statusCode);
    }
    return body.cast<String, dynamic>();
  }

  Map<String, dynamic> _ensureMap(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw SettlementsApiException('Malformed response — expected object');
    }
    return data;
  }

  List<dynamic> _ensureList(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! List) {
      throw SettlementsApiException('Malformed response — expected list');
    }
    return data;
  }
}

final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  return SettlementsRepository(ref.watch(apiClientProvider));
});
