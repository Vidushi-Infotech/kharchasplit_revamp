import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/group_model.dart';

class GroupsApiException implements Exception {
  GroupsApiException(this.message, {this.statusCode, this.code, this.data});
  final String message;
  final int? statusCode;
  /// Machine-readable error tag from the server (e.g. `UNSETTLED_BALANCES`).
  /// Lets the UI distinguish a "you must acknowledge" 409 from a regular
  /// 409, without parsing the human-readable message.
  final String? code;
  /// Structured payload that accompanies certain errors. For
  /// `UNSETTLED_BALANCES` this carries the pairwise debt breakdown the
  /// "write off and remove" dialog renders.
  final Map<String, dynamic>? data;

  @override
  String toString() => message;
}

/// Pairwise debt entry returned by the backend in the 409
/// `UNSETTLED_BALANCES` payload. Sign convention:
/// * `amount > 0` → the member being removed owes [userName] this much.
/// * `amount < 0` → [userName] owes the member being removed this much.
class PairwiseDebt {
  PairwiseDebt({
    required this.userId,
    required this.userName,
    required this.amount,
  });
  final String userId;
  final String userName;
  final double amount;

  factory PairwiseDebt.fromJson(Map<String, dynamic> j) => PairwiseDebt(
        userId: j['userId']?.toString() ?? '',
        userName: j['userName']?.toString() ?? 'Unknown',
        amount: (j['amount'] is num) ? (j['amount'] as num).toDouble() : 0,
      );
}

/// Carries the body of a 409 `UNSETTLED_BALANCES` response in a typed
/// shape so the dialog can render the list without re-parsing the map.
class UnsettledBalancesInfo {
  UnsettledBalancesInfo({
    required this.memberId,
    required this.memberName,
    required this.currency,
    required this.pairwise,
  });
  final String memberId;
  final String memberName;
  final String currency;
  final List<PairwiseDebt> pairwise;

  factory UnsettledBalancesInfo.fromJson(Map<String, dynamic> j) =>
      UnsettledBalancesInfo(
        memberId: j['memberId']?.toString() ?? '',
        memberName: j['memberName']?.toString() ?? 'Member',
        currency: j['currency']?.toString() ?? 'INR',
        pairwise: (j['pairwise'] is List)
            ? (j['pairwise'] as List)
                .whereType<Map>()
                .map((e) =>
                    PairwiseDebt.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : <PairwiseDebt>[],
      );
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

  /// Download a multi-sheet .xlsx export for the group.
  ///
  /// Returns `(bytes, filename)`. The filename is taken from the
  /// `Content-Disposition` header so the receiver sees the same
  /// `kharchasplit_<groupname>_<date>.xlsx` the backend generated.
  Future<({List<int> bytes, String filename})> exportGroup(String groupId) async {
    final res = await _client.dio.get<List<int>>(
      '/groups/$groupId/export',
      options: Options(
        responseType: ResponseType.bytes,
        // Don't apply the JSON-envelope validator — this endpoint returns
        // raw xlsx bytes on success and a JSON envelope only on failure.
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (res.statusCode != 200 || res.data == null) {
      // Body may be a JSON error envelope (when Dio decoded it) or text bytes.
      String msg = 'Failed to export (status ${res.statusCode})';
      final body = res.data;
      if (body is List<int> && body.isNotEmpty) {
        try {
          final decoded = utf8.decode(body);
          final json = jsonDecode(decoded);
          if (json is Map && json['error'] is String) msg = json['error'] as String;
        } catch (_) {/* not JSON; keep generic */}
      }
      throw GroupsApiException(msg, statusCode: res.statusCode);
    }
    // Parse filename out of Content-Disposition: attachment; filename="…"
    String filename = 'kharchasplit_$groupId.xlsx';
    final disposition = res.headers.value('content-disposition');
    if (disposition != null) {
      final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      if (match != null) filename = match.group(1)!;
    }
    return (bytes: res.data!, filename: filename);
  }

  /// Leave a group (remove yourself). Backend rejects with 409 if you have
  /// any unsettled balance with another member.
  Future<void> leave({required String groupId, required String userId}) async {
    final res = await _client.dio.delete('/groups/$groupId/members/$userId');
    _ensureSuccess(res);
  }

  /// Admin-only: remove another member from the group. Same endpoint as
  /// [leave]; the backend enforces admin access when targeting someone else.
  ///
  /// Two-step protocol for unsettled balances:
  /// * First call (default) — if the target member has any unsettled debt
  ///   the backend returns 409 with `code: 'UNSETTLED_BALANCES'`. We
  ///   rethrow as a typed [GroupsApiException] whose `code` and `data`
  ///   carry the pairwise breakdown so the dialog can render it.
  /// * Second call — pass [acknowledgeUnsettledDebt] = true to authorize
  ///   the write-off; the backend creates completed settlement rows that
  ///   zero out the balance before removing the member.
  Future<void> removeMember({
    required String groupId,
    required String userId,
    bool acknowledgeUnsettledDebt = false,
  }) async {
    try {
      final res = await _client.dio.delete(
        '/groups/$groupId/members/$userId',
        data: acknowledgeUnsettledDebt
            ? {'acknowledgeUnsettledDebt': true}
            : null,
      );
      _ensureSuccess(res);
    } on DioException catch (e) {
      final res = e.response;
      final body = res?.data;
      if (body is Map) {
        final msg = (body['error'] ?? body['message'] ?? e.message ?? 'Request failed')
            .toString();
        final code = body['code']?.toString();
        final data = body['data'];
        throw GroupsApiException(
          msg,
          statusCode: res?.statusCode,
          code: code,
          data: data is Map ? Map<String, dynamic>.from(data) : null,
        );
      }
      rethrow;
    }
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
