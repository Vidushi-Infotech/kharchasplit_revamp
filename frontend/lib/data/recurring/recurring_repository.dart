import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// How often a recurring expense repeats (server `frequency`).
enum RecurringFrequency {
  weekly('weekly'),
  biweekly('biweekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurringFrequency(this.apiValue);
  final String apiValue;

  String get label => switch (this) {
        RecurringFrequency.weekly => 'Every week',
        RecurringFrequency.biweekly => 'Every 2 weeks',
        RecurringFrequency.monthly => 'Every month',
        RecurringFrequency.yearly => 'Every year',
      };

  static RecurringFrequency? fromApi(Object? v) {
    for (final f in values) {
      if (f.apiValue == v) return f;
    }
    return null;
  }
}

class RecurringApiException implements Exception {
  RecurringApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;

  /// e.g. `CANNOT_RESUME` (409, someone left / group archived),
  /// `SPLIT_MISMATCH`, `NOT_GROUP_MEMBER`.
  final String? code;

  @override
  String toString() => message;
}

/// A recurring expense rule (GET /recurring/:id, GET /groups/:id/recurring).
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.template,
    required this.frequency,
    required this.anchorDate,
    required this.nextDate,
    this.endDate,
    required this.paused,
    this.pauseReason,
  });

  final String id;
  final String groupId;
  final String? createdBy;

  /// The expense created each time: description, amount (string), currency,
  /// category, notes, splitType, splitMeta, payers [{userId, amount}],
  /// participants [{userId, amount, percentage, shares}].
  final Map<String, dynamic> template;
  final RecurringFrequency frequency;

  /// Calendar days as 'YYYY-MM-DD' (India).
  final String anchorDate;
  final String nextDate;
  final String? endDate;

  final bool paused;

  /// Why it paused: 'paused' (by hand), 'ended', or a sentence from the
  /// server ("someone in it has left the group", …).
  final String? pauseReason;

  String get description => (template['description'] as String?) ?? '';
  double get amount => double.tryParse('${template['amount']}') ?? 0;
  bool get ended => paused && pauseReason == 'ended';

  factory RecurringRule.fromJson(Map<String, dynamic> j) => RecurringRule(
        id: j['id'] as String,
        groupId: j['groupId'] as String,
        createdBy: j['createdBy'] as String?,
        template: (j['template'] as Map?)?.cast<String, dynamic>() ?? const {},
        frequency: RecurringFrequency.fromApi(j['frequency']) ?? RecurringFrequency.monthly,
        anchorDate: j['anchorDate'] as String,
        nextDate: j['nextDate'] as String,
        endDate: j['endDate'] as String?,
        paused: j['paused'] == true,
        pauseReason: j['pauseReason'] as String?,
      );
}

class RecurringRepository {
  RecurringRepository(this._client);
  final ApiClient _client;

  Future<List<RecurringRule>> listForGroup(String groupId) async {
    final body = _ok(await _client.dio.get('/groups/$groupId/recurring'));
    return ((body['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RecurringRule.fromJson)
        .toList();
  }

  Future<RecurringRule> get(String ruleId) async =>
      _rule(await _client.dio.get('/recurring/$ruleId'));

  /// "This and future": change the expense it creates, how often, or when
  /// it ends (`clearEndDate` removes the end date). Expenses already
  /// created are not touched.
  Future<RecurringRule> update(
    String ruleId, {
    Map<String, dynamic>? template,
    RecurringFrequency? frequency,
    String? endDate,
    bool clearEndDate = false,
  }) async =>
      _rule(await _client.dio.put('/recurring/$ruleId', data: {
        'template': ?template,
        if (frequency != null) 'frequency': frequency.apiValue,
        if (endDate != null || clearEndDate) 'endDate': endDate,
      }));

  Future<RecurringRule> pause(String ruleId) async =>
      _rule(await _client.dio.post('/recurring/$ruleId/pause'));

  /// Resumes from the next date on or after today (missed dates are
  /// skipped). Throws [RecurringApiException] with code `CANNOT_RESUME`.
  Future<RecurringRule> resume(String ruleId) async =>
      _rule(await _client.dio.post('/recurring/$ruleId/resume'));

  /// Stop repeating; expenses already created stay.
  Future<void> stop(String ruleId) async =>
      _ok(await _client.dio.delete('/recurring/$ruleId'));

  RecurringRule _rule(Response res) {
    final data = _ok(res)['data'];
    if (data is! Map<String, dynamic>) {
      throw RecurringApiException('Malformed response — expected a rule');
    }
    return RecurringRule.fromJson(data);
  }

  Map<String, dynamic> _ok(Response res) {
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      throw RecurringApiException(
        (body is Map ? body['error'] : null)?.toString() ??
            'Request failed (status ${res.statusCode})',
        statusCode: res.statusCode,
        code: body is Map ? body['code'] as String? : null,
      );
    }
    return body.cast<String, dynamic>();
  }
}

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(apiClientProvider)),
);
