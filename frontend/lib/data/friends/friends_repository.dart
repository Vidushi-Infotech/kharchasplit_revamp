import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/user_model.dart';

class FriendsApiException implements Exception {
  FriendsApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// One group's contribution to a friend's balance.
class FriendGroupBalance {
  const FriendGroupBalance({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.net,
    this.isDirect = false,
  });

  final String groupId;
  final String groupName;

  /// ISO code from the server (e.g. `INR`).
  final String currency;

  /// Positive = the friend owes you in this group; negative = you owe them.
  final double net;

  /// The hidden group holding non-group expenses with this friend.
  final bool isDirect;

  factory FriendGroupBalance.fromJson(Map<String, dynamic> json) =>
      FriendGroupBalance(
        groupId: json['groupId'] as String,
        groupName: (json['groupName'] as String?) ?? '',
        currency: (json['currency'] as String?) ?? 'INR',
        net: (json['net'] as num?)?.toDouble() ?? 0,
        isDirect: json['isDirect'] == true,
      );
}

/// A friend with their balance across every group, from the server ledger
/// (GET /users/:id/friends) — the same numbers as the group Balances tabs.
class FriendBalance {
  const FriendBalance({
    required this.user,
    required this.net,
    required this.sharedGroupCount,
    this.directGroupId,
    required this.groups,
  });

  final UserModel user;

  /// Positive = the friend owes you overall; negative = you owe them.
  final double net;

  /// Groups you are both currently members of. Can be 0 for someone who
  /// left a shared group but still has an open balance with you.
  final int sharedGroupCount;

  /// The hidden group for non-group expenses with them; null until the
  /// first one (create via GroupsRepository.directGroupWith).
  final String? directGroupId;

  /// Groups with an open balance, largest first.
  final List<FriendGroupBalance> groups;

  bool get isSettled => net.abs() < 0.005;

  factory FriendBalance.fromJson(Map<String, dynamic> json) => FriendBalance(
        user: UserModel.fromJson(json),
        net: (json['net'] as num?)?.toDouble() ?? 0,
        sharedGroupCount: (json['sharedGroupCount'] as num?)?.toInt() ?? 0,
        directGroupId: json['directGroupId'] as String?,
        groups: ((json['groups'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FriendGroupBalance.fromJson)
            .toList(),
      );
}

class FriendsRepository {
  FriendsRepository(this._client);
  final ApiClient _client;

  /// Friends of [userId] (must be the signed-in user), open balances first.
  Future<List<FriendBalance>> list(String userId) async {
    final res = await _client.dio.get('/users/$userId/friends');
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw FriendsApiException(msg, statusCode: res.statusCode);
    }
    return ((body['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FriendBalance.fromJson)
        .toList();
  }
}

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(apiClientProvider)),
);
