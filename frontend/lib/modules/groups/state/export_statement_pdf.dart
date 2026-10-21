import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import 'export_statement_data.dart';

/// Fonts for the statement: Noto Sans (₹ and all Latin text) with Noto
/// Sans Devanagari as fallback for Hindi names. Loaded from assets on the
/// UI isolate ([loadStatementFonts]) and passed to the render isolate.
class StatementFonts {
  const StatementFonts({required this.regular, required this.bold, this.devanagari});
  final ByteData regular;
  final ByteData bold;
  final ByteData? devanagari;
}

/// What `compute` sends to the render isolate.
class StatementPdfJob {
  const StatementPdfJob(this.statement, this.fonts);
  final GroupStatement statement;
  final StatementFonts? fonts;
}

/// `compute` entry point.
Future<Uint8List> renderStatementJob(StatementPdfJob job) =>
    renderGroupStatementPdf(job.statement, fonts: job.fonts);

/// Renders a [GroupStatement] to PDF bytes. Top-level and free of Flutter
/// so it can run in a background isolate via `compute` — a group with
/// thousands of expenses lays out many pages.
///
/// With [fonts] the PDF uses Noto Sans, so ₹ and names in Hindi print as
/// they are (Devanagari is drawn without complex shaping — the pdf package
/// has none — so some conjuncts look simplified). Without fonts (tests) it
/// falls back to the built-in Helvetica: Latin-1 only, currency codes
/// instead of symbols, other characters replaced by [statementPdfSafe].
Future<Uint8List> renderGroupStatementPdf(GroupStatement s, {StatementFonts? fonts}) {
  final money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: fonts == null
        ? '${s.currencyCode} '
        : CurrencyFormatter.symbolFor(s.currencyCode),
    decimalDigits: 2,
  );
  String amount(double v) => money.format(v);
  String signed(double v) =>
      v.abs() < 0.005 ? amount(0) : '${v > 0 ? '+' : '-'}${amount(v.abs())}';
  final dates = DateFormat('d MMM yyyy');
  String t(String text) => fonts == null ? statementPdfSafe(text) : text;

  final doc = pw.Document(
    title: '${AppStrings.statementTitle} - ${t(s.groupName)}',
    creator: 'KharchaSplit',
    theme: fonts == null
        ? null
        : pw.ThemeData.withFont(
            base: pw.Font.ttf(fonts.regular),
            bold: pw.Font.ttf(fonts.bold),
            fontFallback: [
              if (fonts.devanagari != null) pw.Font.ttf(fonts.devanagari!),
            ],
          ),
  );
  final heading = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
  const muted = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
  const brand = PdfColor.fromInt(0xFF1A7A6E);

  pw.Widget table(
    List<String> headers,
    List<List<String>> rows,
    Map<int, pw.Alignment> align,
  ) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: null,
    headerStyle: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(color: brand),
    cellStyle: const pw.TextStyle(fontSize: 9),
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    cellAlignments: align,
    headerAlignments: align,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            AppStrings.statementGenerated(dates.format(s.generatedAt)),
            style: muted,
          ),
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: muted),
        ],
      ),
      build: (ctx) => [
        pw.Text(AppStrings.statementTitle, style: muted),
        pw.Text(
          t(s.groupName),
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: brand,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(AppStrings.statementPeriod(t(s.periodLabel)), style: muted),
        pw.SizedBox(height: 16),
        pw.Text(AppStrings.statementTotals, style: heading),
        pw.SizedBox(height: 4),
        pw.Text(
          '${AppStrings.totalGroupSpending}: ${amount(s.totalSpending)} '
          '(${AppStrings.totalsExpenseCount(s.expenses.length)})',
        ),
        pw.SizedBox(height: 16),
        pw.Text(AppStrings.statementBalances, style: heading),
        pw.SizedBox(height: 6),
        table(
          [AppStrings.statementMember, AppStrings.statementNet],
          [
            for (final b in s.balances) [t(b.name), signed(b.net)],
          ],
          {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 12),
        pw.Text(AppStrings.statementWhoOwes, style: heading),
        if (s.simplified) pw.Text(AppStrings.statementSimplified, style: muted),
        pw.SizedBox(height: 4),
        if (s.debts.isEmpty)
          pw.Text(AppStrings.statementAllSettled)
        else
          for (final d in s.debts)
            pw.Bullet(
              text:
                  '${AppStrings.statementOwes(t(d.from), t(d.to))}: ${amount(d.amount)}',
            ),
        pw.SizedBox(height: 16),
        pw.Text(AppStrings.expenses, style: heading),
        pw.SizedBox(height: 6),
        if (s.expenses.isEmpty)
          pw.Text(AppStrings.statementNoExpenses)
        else
          table(
            [
              AppStrings.statementDate,
              AppStrings.statementDescription,
              AppStrings.paidBy,
              AppStrings.statementAmount,
            ],
            [
              for (final e in s.expenses)
                [
                  dates.format(e.date),
                  t(e.description),
                  t(e.paidBy),
                  amount(e.amount),
                ],
            ],
            {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
          ),
        if (s.pendingExcluded > 0) ...[
          pw.SizedBox(height: 10),
          pw.Text(AppStrings.statementPendingNote, style: muted),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Keeps Latin-1 (what Helvetica can draw); anything else becomes "?" so
/// a Hindi name or an emoji never breaks the layout.
String statementPdfSafe(String input) =>
    String.fromCharCodes(input.runes.map((r) => r <= 0xFF ? r : 0x3F));
