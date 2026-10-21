import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/export_file_share.dart';
import '../../../data/export/export_repository.dart';
import '../state/export_statement_data.dart';
import '../state/export_statement_pdf.dart';
import '../state/group_detail_provider.dart';
import '../state/group_totals_calculator.dart';
import '../state/group_totals_provider.dart';
import 'export_statement_period_sheet.dart';
import 'group_totals_cards.dart';

/// "Export to CSV" and "Download group statement (PDF)" in the group ⋮
/// menu, next to "Export to Excel".
///
/// The top bar has no group id or ref, so the handler takes both from the
/// context: the id from the `/home/groups/:groupId` route, providers from
/// the enclosing ProviderScope. Only shown once the detail has loaded.
const exportCsvMenuValue = 'export_csv';
const exportPdfMenuValue = 'export_pdf';

bool isGroupExportMenuValue(String value) =>
    value == exportCsvMenuValue || value == exportPdfMenuValue;

List<PopupMenuEntry<String>> buildGroupExportMenuItems(bool isDark) => [
  _item(
    exportCsvMenuValue,
    Icons.table_chart_outlined,
    AppStrings.exportToCsv,
    isDark,
  ),
  _item(
    exportPdfMenuValue,
    Icons.picture_as_pdf_outlined,
    AppStrings.exportStatementPdf,
    isDark,
  ),
];

PopupMenuItem<String> _item(
  String value,
  IconData icon,
  String label,
  bool isDark,
) => PopupMenuItem(
  value: value,
  child: Row(
    children: [
      Icon(icon, size: 18, color: AppColors.textPrimary(isDark)),
      const SizedBox(width: 10),
      Flexible(child: Text(label)),
    ],
  ),
);

Future<void> handleGroupExportMenuValue(
  BuildContext context,
  String value,
) async {
  final groupId = GoRouterState.of(context).pathParameters['groupId'];
  if (groupId == null) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final detail = container.read(groupDetailProvider(groupId)).value;
  if (detail == null) return;

  if (value == exportCsvMenuValue) {
    // The CSV comes from the server; the PDF below is built on the phone
    // from loaded data, so it also works offline.
    if (container.read(isOfflineProvider)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(AppStrings.offlineNoConnection)),
      );
      return;
    }
    await runExportWithProgress(
      context,
      prepare: () async {
        final file = await container
            .read(exportRepositoryProvider)
            .groupCsv(groupId);
        return ExportShareRequest(
          bytes: file.bytes,
          filename: file.filename,
          mimeType: csvMimeType,
          subject: AppStrings.exportShareSubject(detail.group.name),
        );
      },
    );
    return;
  }

  final period = await showExportStatementPeriodSheet(
    context,
    // Follow the Totals tab when it is open; otherwise the whole history.
    initial: container.exists(groupTotalsPeriodProvider(groupId))
        ? container.read(groupTotalsPeriodProvider(groupId))
        : TotalsPeriod.allTime,
  );
  if (period == null || !context.mounted) return;
  await runExportWithProgress(
    context,
    prepare: () async {
      final now = DateTime.now();
      final data = buildGroupStatement(
        detail: detail,
        period: period,
        periodLabel: totalsPeriodLabel(period),
        now: now,
      );
      // Layout of a long statement takes a while — keep it off the UI
      // isolate so the progress dialog keeps spinning.
      final bytes = await compute(
        renderStatementJob,
        StatementPdfJob(data, await loadStatementFonts()),
      );
      return ExportShareRequest(
        bytes: bytes,
        filename: statementFileName(detail.group.name, now),
        mimeType: pdfMimeType,
        subject: AppStrings.exportShareSubject(detail.group.name),
      );
    },
  );
}

/// `kharchasplit_<group>_statement_<yyyy-MM-dd>.pdf`, file-system safe.
String statementFileName(String groupName, DateTime now) {
  final safe = groupName
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final name = safe.isEmpty ? 'group' : safe;
  return 'kharchasplit_${name}_statement_${DateFormat('yyyy-MM-dd').format(now)}.pdf';
}

/// Noto Sans + Noto Sans Devanagari from assets (null if they can't be
/// loaded — the PDF then falls back to the built-in font).
Future<StatementFonts?> loadStatementFonts() async {
  try {
    final loaded = await Future.wait([
      rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
    ]);
    return StatementFonts(regular: loaded[0], bold: loaded[1], devanagari: loaded[2]);
  } catch (_) {
    return null;
  }
}
