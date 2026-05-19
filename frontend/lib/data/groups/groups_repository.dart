import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/group_model.dart';

class GroupsApiException implements Exception {
  GroupsApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CreateGroupMember {
  CreateGroupMember({
    required this.userId,
    required this.name,
    this.phoneNumber,
    this.email,
  });

  final String userId;
  final String name;
  final String? phoneNumber;
  final String? email;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (email != null) 'email': email,
      };
}

class GroupsRepository {
  GroupsRepository(this._client);
  final ApiClient _client;

  Future<List<GroupModel>> listForUser(
    String userId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.dio.get(
      '/groups',
      queryParameters: {
        'userId': userId,
        'page': page,
        'limit': limit,
      },
    );
    final data = _ensureSuccessList(res);
    return data
        .whereType<Map<String, dynamic>>()
        .map(GroupModel.fromJson)
        .toList();
  }

  Future<GroupModel> getById(String groupId) async {
    final res = await _client.dio.get('/groups/$groupId');
    final data = _ensureSuccessMap(res);
    return GroupModel.fromJson(data);
  }

  Future<GroupModel> create({
    required String name,
    String? description,
    String? coverImageBase64,
    String currency = 'INR',
    List<CreateGroupMember> members = const [],
  }) async {
    final res = await _client.dio.post(
      '/groups',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (coverImageBase64 != null) 'coverImageBase64': coverImageBase64,
        'currency': currency,
        'members': members.map((m) => m.toJson()).toList(),
      },
    );
    final data = _ensureSuccessMap(res);
    return GroupModel.fromJson(data);
  }

  Future<GroupModel> update(
    String groupId, {
    String? name,
    String? description,
    String? coverImageBase64,
    String? currency,
  }) async {
    final res = await _client.dio.put(
      '/groups/$groupId',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (coverImageBase64 != null) 'coverImageBase64': coverImageBase64,
        if (currency != null) 'currency': currency,
      },
    );
    final data = _ensureSuccessMap(res);
    return GroupModel.fromJson(data);
  }

  Future<void> delete(String groupId) async {
    final res = await _client.dio.delete('/groups/$groupId');
    _ensureSuccess(res);
  }

  /// Leave a group (remove yourself). Backend rejects with 409 if you have
  /// any unsettled balance with another member.
  Future<void> leave({required String groupId, required String userId}) async {
    final res = await _client.dio.delete('/groups/$groupId/members/$userId');
    _ensureSuccess(res);
  }

  /// Admin-only: remove another member from the group. Same endpoint as
  /// [leave]; the backend enforces admin access when targeting someone else.
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final res = await _client.dio.delete('/groups/$groupId/members/$userId');
    _ensureSuccess(res);
  }

  /// Send a "you owe me" push reminder to another member of the group.
  /// Backend rejects with 400 if the target doesn't actually owe the
  /// caller money, and 429 if a reminder for the same pair was sent in
  /// the last 6 hours.
  Future<void> sendReminder({
    required String groupId,
    required String userId,
  }) async {
    final res = await _client.dio.post('/groups/$groupId/remind/$userId');
    _ensureSuccess(res);
  }

  /// Invite someone to a group by phone number. The backend transparently
  /// adds registered users directly and creates a placeholder + pending
  /// invite for non-registered ones.
  Future<void> invitePhone({
    required String groupId,
    required String name,
    required String phoneNumber,
    String? email,
  }) async {
    final normalized = _normalizePhone(phoneNumber);
    final res = await _client.dio.post(
      '/groups/$groupId/pending-members',
      data: {
        'name': name,
        'phoneNumber': normalized,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    _ensureSuccess(res);
  }

  /// Email-only invite fallback. Sends an SMTP "you were added to <group> by
  /// <inviter>" email with install links. Does not modify group membership
  /// on the backend — purely a delivery channel for when WhatsApp/WATI
  /// isn't viable.
  Future<void> inviteByEmail({
    required String groupId,
    required String email,
    String? name,
  }) async {
    final res = await _client.dio.post(
      '/groups/$groupId/invite-email',
      data: {
        'email': email.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );
    _ensureSuccess(res);
  }

  String _normalizePhone(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (RegExp(r'^\d{10}$').hasMatch(cleaned)) return '+91$cleaned';
    return cleaned;
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw GroupsApiException(msg, statusCode: res.statusCode);
    }
    return body.cast<String, dynamic>();
  }

  Map<String, dynamic> _ensureSuccessMap(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw GroupsApiException('Malformed response — expected object in data');
    }
    return data;
  }

  List<dynamic> _ensureSuccessList(Response res) {
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is! List) {
      throw GroupsApiException('Malformed response — expected list in data');
    }
    return data;
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(apiClientProvider));
});
