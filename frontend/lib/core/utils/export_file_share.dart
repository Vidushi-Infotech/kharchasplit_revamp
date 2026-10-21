import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_strings.dart';
import '../services/haptic_service.dart';

const csvMimeType = 'text/csv';
const pdfMimeType = 'application/pdf';

/// Writes [bytes] to the temp directory and opens the share sheet — the
/// same mechanism as the group "Export to Excel" action. The OS reaps the
/// temp file on its own schedule.
Future<void> shareExportFile({
  required List<int> bytes,
  required String filename,
  required String mimeType,
  required String subject,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: subject,
      text: text,
    ),
  );
}

/// Runs [prepare] behind a blocking progress dialog, then shares what it
/// returns. Any failure becomes a snackbar — never a crash or a silent
/// no-op. The dialog sits on the root navigator so the floating tab bar
/// can't cover it.
Future<void> runExportWithProgress(
  BuildContext context, {
  required Future<ExportShareRequest> Function() prepare,
}) async {
  HapticService.instance.selection();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => const _ExportProgressDialog(),
  );
  var dialogOpen = true;
  void closeDialog() {
    if (dialogOpen && navigator.mounted) navigator.pop();
    dialogOpen = false;
  }

  try {
    final req = await prepare();
    closeDialog();
    await shareExportFile(
      bytes: req.bytes,
      filename: req.filename,
      mimeType: req.mimeType,
      subject: req.subject,
      text: req.text,
    );
  } catch (e) {
    closeDialog();
    messenger?.showSnackBar(
      SnackBar(
        // Transport errors read as gibberish; API errors carry a message.
        content: Text(
          e is DioException
              ? AppStrings.exportFailed
              : '${AppStrings.exportFailed}: $e',
        ),
      ),
    );
  }
}

class ExportShareRequest {
  const ExportShareRequest({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.subject,
    this.text,
  });

  final List<int> bytes;
  final String filename;
  final String mimeType;
  final String subject;
  final String? text;
}

class _ExportProgressDialog extends StatelessWidget {
  const _ExportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: AppStrings.exportPreparing,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppStrings.exportPreparing,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
