import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// One active sign-in session as returned by `GET /auth/sessions`.
class SessionModel {
  const SessionModel({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    required this.isCurrent,
    this.deviceName,
    this.platform,
    this.osVersion,
    this.appVersion,
    this.ipAddress,
    this.lastUsedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isCurrent;
  final String? deviceName;
  final String? platform;
  final String? osVersion;
  final String? appVersion;
  final String? ipAddress;
  final DateTime? lastUsedAt;

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullable(Object? raw) =>
        raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
    return SessionModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isCurrent: (json['isCurrent'] as bool?) ?? false,
      deviceName: json['deviceName'] as String?,
      platform: json['platform'] as String?,
      osVersion: json['osVersion'] as String?,
      appVersion: json['appVersion'] as String?,
      ipAddress: json['ipAddress'] as String?,
      lastUsedAt: parseNullable(json['lastUsedAt']),
    );
  }
}

class SessionsNotifier extends AsyncNotifier<List<SessionModel>> {
  @override
  Future<List<SessionModel>> build() async {
    return _fetch();
  }

  Future<List<SessionModel>> _fetch() async {
    final client = ref.read(apiClientProvider);
    final currentToken = await client.tokens.readRefreshToken();
    final res = await client.dio.get(
      '/auth/sessions',
      options: currentToken == null
          ? null
          : Options(headers: {'X-Current-Refresh-Token': currentToken}),
    );
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      throw Exception('Failed to load sessions');
    }
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SessionModel.fromJson)
        .toList(growable: false);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> revoke(String id) async {
    final client = ref.read(apiClientProvider);
    await client.dio.delete('/auth/sessions/$id');
    final current = state.value ?? const <SessionModel>[];
    state = AsyncData(current.where((s) => s.id != id).toList());
  }

  /// Revoke every session except this device's. The backend keeps the
  /// session matching the stored refresh token.
  Future<int> revokeAllOthers() async {
    final client = ref.read(apiClientProvider);
    final keep = await client.tokens.readRefreshToken();
    final res = await client.dio.delete(
      '/auth/sessions',
      data: keep == null ? null : {'keepRefreshToken': keep},
    );
    final body = res.data;
    final revoked = body is Map &&
            body['data'] is Map &&
            (body['data'] as Map)['revokedCount'] is int
        ? (body['data'] as Map)['revokedCount'] as int
        : 0;
    await refresh();
    return revoked;
  }
}

final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, List<SessionModel>>(
  SessionsNotifier.new,
);
