import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/activity_model.dart';

class ActivitiesApiException implements Exception {
  ActivitiesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ActivityFeedResult {
  ActivityFeedResult({required this.activities, required this.unreadCount});
  final List<ActivityModel> activities;
  final int unreadCount;
}

class ActivitiesRepository {
  ActivitiesRepository(this._client);
  final ApiClient _client;

  Future<ActivityFeedResult> listForUser(
    String userId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.dio.get(
      '/activities',
      queryParameters: {
        'userId': userId,
        'page': page,
        'limit': limit,
      },
    );
    final body = _ensureSuccess(res);
    final raw = body['data'];
    final activities = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(ActivityModel.fromJson)
            .toList()
        : <ActivityModel>[];
    return ActivityFeedResult(
      activities: activities,
      unreadCount: (body['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> getUnreadCount(String userId) async {
    final res = await _client.dio.get(
      '/activities/unread/count',
      queryParameters: {'userId': userId},
    );
    final body = _ensureSuccess(res);
    final data = body['data'];
    if (data is Map && data['unreadCount'] is num) {
      return (data['unreadCount'] as num).toInt();
    }
    return 0;
  }

  Future<void> markAsRead(String activityId) async {
    final res = await _client.dio.patch('/activities/$activityId/read');
    _ensureSuccess(res);
  }

  Future<void> markAllAsRead(String userId) async {
    final res = await _client.dio.patch(
      '/activities/read-all',
      data: {'userId': userId},
    );
    _ensureSuccess(res);
  }

  Map<String, dynamic> _ensureSuccess(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg = (body is Map ? body['error'] : null)?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw ActivitiesApiException(msg, statusCode: res.statusCode);
    }
    return body.cast<String, dynamic>();
  }
}

final activitiesRepositoryProvider = Provider<ActivitiesRepository>((ref) {
  return ActivitiesRepository(ref.watch(apiClientProvider));
});
