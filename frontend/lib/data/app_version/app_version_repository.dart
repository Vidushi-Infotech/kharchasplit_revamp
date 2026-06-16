import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// Server-side update gating config. Comes from GET /app-version.
class AppVersionConfig {
  AppVersionConfig({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.forceUpdateMessage,
    required this.softUpdateMessage,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
  });

  /// Latest released version (e.g. "3.3.0"). No build code suffix.
  final String latestVersion;

  /// Anything strictly below this triggers a FORCE update.
  final String minSupportedVersion;

  /// Shown in the blocking dialog when current < minSupportedVersion.
  final String forceUpdateMessage;

  /// Shown in the dismissible dialog when current < latestVersion.
  final String softUpdateMessage;

  final String androidStoreUrl;
  final String iosStoreUrl;

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) {
    final stores = (json['storeUrls'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppVersionConfig(
      latestVersion: (json['latestVersion'] as String?) ?? '0.0.0',
      minSupportedVersion: (json['minSupportedVersion'] as String?) ?? '0.0.0',
      forceUpdateMessage: (json['forceUpdateMessage'] as String?) ??
          'A critical update is required.',
      softUpdateMessage: (json['softUpdateMessage'] as String?) ??
          'A new version is available.',
      androidStoreUrl: (stores['android'] as String?) ??
          'https://play.google.com/store/apps/details?id=com.kharchasplit',
      iosStoreUrl: (stores['ios'] as String?) ??
          'https://apps.apple.com/app/id6754237285',
    );
  }
}

class AppVersionApiException implements Exception {
  AppVersionApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class AppVersionRepository {
  AppVersionRepository(this._client);
  final ApiClient _client;

  /// Fetch the server's current version gating config.
  /// Returns null on any failure (network down, 500, malformed). The caller
  /// must treat null as "no opinion — skip the update prompt this time"
  /// rather than crashing or showing an error to the user.
  Future<AppVersionConfig?> fetch() async {
    try {
      final res = await _client.dio.get('/app-version');
      final body = res.data;
      if (body is! Map || body['success'] != true) return null;
      final data = body['data'];
      if (data is! Map<String, dynamic>) return null;
      return AppVersionConfig.fromJson(data);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

final appVersionRepositoryProvider = Provider<AppVersionRepository>((ref) {
  return AppVersionRepository(ref.watch(apiClientProvider));
});
