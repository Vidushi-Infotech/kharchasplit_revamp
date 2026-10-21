import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/connectivity_provider.dart';
import '../../../core/utils/export_file_share.dart';
import '../../../data/export/export_repository.dart';
import '../../auth/state/auth_provider.dart';

/// Account → "Export my expenses (CSV)": every expense the signed-in user
/// is part of, across all groups (GET /users/:id/expenses.csv), shared via
/// the system share sheet.
Future<void> exportMyExpensesCsv(BuildContext context, WidgetRef ref) async {
  final myId = ref.read(myIdProvider);
  if (myId == null) return;
  if (ref.read(isOfflineProvider)) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(AppStrings.offlineNoConnection)),
    );
    return;
  }
  final repo = ref.read(exportRepositoryProvider);
  await runExportWithProgress(
    context,
    prepare: () async {
      final file = await repo.myExpensesCsv(myId);
      return ExportShareRequest(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: csvMimeType,
        subject: AppStrings.exportShareSubject(AppStrings.exportMyExpensesCsv),
      );
    },
  );
}
