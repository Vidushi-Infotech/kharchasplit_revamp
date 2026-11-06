import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_client.dart';
import 'auth_provider.dart';

/// Result of an export attempt — used by the UI to decide what feedback
/// to show.
class DataExportResult {
  const DataExportResult({
    required this.file,
    required this.counts,
  });

  final XFile file;
  final Map<String, int> counts;
}

class DataExportService {
  DataExportService(this._ref);
  final Ref _ref;

  /// Fetches `GET /users/:id/export`, writes the JSON payload to a temp
  /// file, and opens the system share sheet so the user can save it.
  Future<DataExportResult> exportAndShare() async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final client = _ref.read(apiClientProvider);

    final res = await client.dio.get('/users/${user.id}/export');
    final body = res.data;
    if (body is! Map || body['success'] != true || body['data'] is! Map) {
      throw Exception('Export response was malformed');
    }
    final payload = body['data'] as Map<String, dynamic>;

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final filePath = '${tempDir.path}/kharchasplit-export-$timestamp.json';
    final file = File(filePath);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));

    final share = SharePlus.instance;
    await share.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/json')],
        subject: 'KharchaSplit data export',
        text:
            'Your KharchaSplit data export (${(payload['counts'] as Map?)?['expenses'] ?? 0} expenses).',
      ),
    );

    final rawCounts = (payload['counts'] as Map?) ?? const {};
    final counts = <String, int>{
      for (final entry in rawCounts.entries)
        entry.key.toString(): (entry.value as num? ?? 0).toInt(),
    };

    return DataExportResult(file: XFile(filePath), counts: counts);
  }
}

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(ref);
});
