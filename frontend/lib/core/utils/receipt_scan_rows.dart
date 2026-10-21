/// One line of OCR text with where it sits on the photo (pixels).
class ReceiptOcrLine {
  const ReceiptOcrLine(
    this.text, {
    required this.left,
    required this.top,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double bottom;

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

/// Rebuilds the receipt's rows from OCR lines. ML Kit returns text in
/// blocks, so a bill's label column ("Grand Total") and amount column
/// ("1,102.00") often come back far apart; lines whose vertical centre sits
/// inside another line's height are the same row and are joined left to
/// right. Rows are returned top to bottom, one per line. Pure Dart.
String receiptRowsText(List<ReceiptOcrLine> lines) {
  final sorted = [...lines.where((l) => l.text.trim().isNotEmpty)]
    ..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<ReceiptOcrLine>>[];
  for (final line in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && _sameRow(row, line)) {
      row.add(line);
    } else {
      rows.add([line]);
    }
  }
  return rows
      .map((row) {
        row.sort((a, b) => a.left.compareTo(b.left));
        return row.map((l) => l.text.trim()).join('  ');
      })
      .join('\n');
}

bool _sameRow(List<ReceiptOcrLine> row, ReceiptOcrLine line) {
  final top = row.map((l) => l.top).reduce((a, b) => a < b ? a : b);
  final bottom = row.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
  final rowCenter = (top + bottom) / 2;
  // Both centres inside each other's band: tolerant of a slightly tilted
  // photo, but two stacked rows never merge.
  return line.centerY > top &&
      line.centerY < bottom &&
      rowCenter > line.top &&
      rowCenter < line.bottom;
}
