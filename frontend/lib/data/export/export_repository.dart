import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class ExportApiException implements Exception {
  ExportApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// A downloaded export: raw bytes plus the server's file name.
typedef ExportFile = ({List<int> bytes, String filename});

/// CSV downloads. The .xlsx ledger stays on GroupsRepository.exportGroup;
/// these follow the same rules (raw bytes, filename from
/// `Content-Disposition`, JSON error envelope only on failure).
class ExportRepository {
  ExportRepository(this._client);
  final ApiClient _client;

  /// Group ledger as CSV: one row per expense, one share column per member.
  Future<ExportFile> groupCsv(String groupId) => _download(
    '/groups/$groupId/export.csv',
    fallbackName: 'kharchasplit_group.csv',
  );

  /// The signed-in user's expenses across every group, as CSV. The server
  /// refuses any id but your own.
  Future<ExportFile> myExpensesCsv(String userId) => _download(
    '/users/$userId/expenses.csv',
    fallbackName: 'kharchasplit_my_expenses.csv',
  );

  Future<ExportFile> _download(
    String path, {
    required String fallbackName,
  }) async {
    final res = await _client.dio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final body = res.data;
    if (res.statusCode != 200 || body == null) {
      var msg = 'Failed to export (status ${res.statusCode})';
      if (body != null && body.isNotEmpty) {
        try {
          final json = jsonDecode(utf8.decode(body));
          if (json is Map && json['error'] is String) {
            msg = json['error'] as String;
          }
        } catch (_) {
          /* not JSON; keep generic */
        }
      }
      throw ExportApiException(msg, statusCode: res.statusCode);
    }
    return (
      bytes: body,
      filename: filenameFromDisposition(
        res.headers.value('content-disposition'),
        fallback: fallbackName,
      ),
    );
  }
}

/// `attachment; filename="x.csv"` → `x.csv`. Path separators are dropped so
/// a hostile header can't write outside the temp directory.
String filenameFromDisposition(String? header, {required String fallback}) {
  if (header == null) return fallback;
  final match = RegExp(r'filename="?([^";]+)"?').firstMatch(header);
  final name = match?.group(1)?.replaceAll(RegExp(r'[/\\]'), '_').trim();
  return (name == null || name.isEmpty || name.startsWith('.'))
      ? fallback
      : name;
}

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(apiClientProvider)),
);
