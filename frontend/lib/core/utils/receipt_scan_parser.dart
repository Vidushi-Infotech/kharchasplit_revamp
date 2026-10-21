import 'receipt_scan_fields.dart';

/// What a receipt photo's text says: the total, the bill date and the
/// merchant. Pure Dart — the OCR itself is InvoiceScannerService; this only
/// reads its text, so it is unit-tested with real-looking Indian receipts
/// (restaurant bills with CGST/SGST, Swiggy/Zomato summaries, fuel slips,
/// supermarket bills, UPI payment screenshots).
///
/// Conservative on purpose: a wrong total is worse than none, so [total]
/// is null unless a line clearly labels it (or a UPI screen shows it).
class ReceiptScanResult {
  const ReceiptScanResult({
    this.total,
    this.totalConfidence = 0,
    this.date,
    this.merchant,
  });

  /// In rupees (or whatever the bill's currency is), 2 decimals.
  final double? total;

  /// 0–1: how sure the parser is about [total] (≥ [minTotalConfidence]
  /// whenever [total] is set).
  final double totalConfidence;
  final DateTime? date;
  final String? merchant;

  bool get isEmpty => total == null && date == null && merchant == null;

  static const minTotalConfidence = 0.5;
}

/// Labels of the total, strongest first. Matched on the lower-cased line
/// with punctuation turned into spaces.
const _strongLabels = [
  'grand total', 'net payable', 'amount payable', 'total payable', //
  'payable amount', 'net amount', 'net amt', 'to pay', 'bill amount',
  'bill amt', 'total amount', 'total amt', 'amount due', 'total due',
  'balance due', 'net total', 'order total', 'bill total', 'total bill',
  'invoice total', 'invoice amount', 'total paid', 'amount paid',
  'paid amount', 'you paid', 'total value', 'net value',
];
const _mediumLabels = ['total', 'sale amount', 'sale', 'nett'];
const _weakLabels = ['amount', 'amt', 'paid'];

/// A labelled line is not the total when what's left of its label says it
/// is a part of it, a tax, a saving or the cash handed over.
final _notTotal = RegExp(
  r'\b(sub ?total|sub|item|items|gst|cgst|sgst|igst|utgst|cess|vat|tax|'
  r'taxes|taxable|discount|disc|saving|savings|saved|save|change|tendered|'
  r'received|round|rounding|roundoff|service|delivery|packing|packaging|'
  r'platform|convenience|tip|qty|quantity|mrp|rate|price|volume|litre|'
  r'litres|ltr|cashback|points|loyalty|balance|wallet|cash|card|fee|'
  r'charges|charge|deposit|advance)\b',
);

/// Words that can't sit next to a strong label without making it a part
/// ("Total GST", "Item Total").
final _notTotalStrong = RegExp(
  r'\b(sub ?total|sub|item|items|gst|cgst|sgst|igst|tax|discount|saving|'
  r'savings|tendered|change|cashback|fee)\b',
);

/// "incl. of all taxes" / "(inclusive of GST)" says nothing about the line.
final _inclusive = RegExp(
  r'\(?\b(incl|inclusive|including|inc)\b\.?\s*(of\s*)?(all\s*)?'
  r'(gst|taxes|tax)?\)?',
);

final _upiContext = RegExp(
  r'paid to|payment successful|transaction successful|upi transaction|'
  r'upi ref|google pay|gpay|phonepe|paytm|bhim|debited from|'
  r'paid successfully',
  caseSensitive: false,
);

class _Candidate {
  _Candidate(this.amount, this.score, this.line);
  final ReceiptAmount amount;
  final int score;
  final int line;
}

/// Reads [text] (OCR output, one receipt row per line).
/// [now] is for tests; dates after it are never returned.
ReceiptScanResult parseReceiptText(String text, {DateTime? now}) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const ReceiptScanResult();
  final total = _findTotal(lines);
  return ReceiptScanResult(
    total: total?.$1,
    totalConfidence: total?.$2 ?? 0,
    date: parseReceiptDate(lines, now ?? DateTime.now()),
    merchant: parseReceiptMerchant(lines),
  );
}

/// (total, confidence) or null.
(double, double)? _findTotal(List<String> lines) {
  final candidates = <_Candidate>[];
  final labelOnly = <int>[];
  for (var i = 0; i < lines.length; i++) {
    final score = _labelScore(lines[i]);
    if (score == null || score == 0) continue;
    final amounts = receiptAmountsIn(lines[i]).where((a) => !a.isNegative);
    if (amounts.isNotEmpty) {
      candidates.add(_Candidate(amounts.last, score, i));
    } else {
      labelOnly.add(i);
    }
  }
  candidates.addAll(_pairColumns(lines, labelOnly));

  if (candidates.isEmpty) return _unlabelledTotal(lines);
  final best = candidates.map((c) => c.score).reduce((a, b) => a > b ? a : b);
  final top = candidates.where((c) => c.score == best).toList()
    ..sort((a, b) => a.line.compareTo(b.line));
  // The lowest one: totals add up down the bill (Total → Grand Total).
  final pick = top.last;
  var confidence = switch (best) {
    >= 10 => 0.9,
    >= 7 => 0.75,
    _ => 0.6,
  };
  if (pick.amount.hasCurrency || pick.amount.hasDecimals) confidence += 0.05;
  if (top.any((c) => c.amount.paise != pick.amount.paise)) confidence -= 0.15;
  if (confidence < ReceiptScanResult.minTotalConfidence) return null;
  return (pick.amount.paise / 100, confidence.clamp(0, 1).toDouble());
}

/// 10 / 7 / 5 for a strong / plain / weak total label, 0 for a line that
/// is a non-total money line (kept out of the column pairing), null when
/// the line has no label at all.
int? _labelScore(String raw) {
  final label = raw
      .toLowerCase()
      .replaceAll(_inclusive, ' ')
      .replaceAll(RegExp(r'[^a-z]+'), ' ')
      .replaceAll(RegExp(r'\b(rs|inr)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (label.isEmpty) return null;
  for (final (labels, score) in [
    (_strongLabels, 10),
    (_mediumLabels, 7),
    (_weakLabels, 5),
  ]) {
    for (final l in labels) {
      final at = RegExp('\\b$l\\b').firstMatch(label);
      if (at == null) continue;
      final rest = label.replaceRange(at.start, at.end, ' ');
      final blocked = score == 10 ? _notTotalStrong : _notTotal;
      return blocked.hasMatch(rest) ? 0 : score;
    }
  }
  return _notTotal.hasMatch(label) ? 0 : null;
}

/// ML Kit sometimes reads a bill's label column and amount column as two
/// runs of lines ("Sub Total / CGST / Grand Total" then "1,000.00 / 25.00 /
/// 1,025.00"). Pairs them up when both runs have the same length; else a
/// lone trailing label takes the amount right below it.
List<_Candidate> _pairColumns(List<String> lines, List<int> labelOnly) {
  final out = <_Candidate>[];
  final labelSet = labelOnly.toSet();
  var i = 0;
  while (i < lines.length) {
    if (!_isLabelLine(lines[i])) {
      i++;
      continue;
    }
    // A run of label lines (any money label, total or not), then a run of
    // amount-only lines.
    final run = <int>[];
    while (i < lines.length && _isLabelLine(lines[i])) {
      run.add(i++);
    }
    final values = <int>[];
    while (i < lines.length && isAmountOnlyLine(lines[i])) {
      values.add(i++);
    }
    for (var k = 0; k < run.length; k++) {
      final idx = run[k];
      if (!labelSet.contains(idx)) continue;
      final int? valueLine = values.length == run.length
          ? values[k]
          : (k == run.length - 1 && values.isNotEmpty ? values.first : null);
      if (valueLine == null) continue;
      final amount = receiptAmountsIn(lines[valueLine]).first;
      if (amount.isNegative) continue;
      out.add(_Candidate(amount, _labelScore(lines[idx])!, idx));
    }
  }
  return out;
}

/// A label with no amount on its line.
bool _isLabelLine(String line) =>
    _labelScore(line) != null && receiptAmountsIn(line).isEmpty;

/// No labelled total: a UPI payment screen shows the amount on its own
/// line ("₹1,234.50"); otherwise a lone ₹ amount on the whole bill.
(double, double)? _unlabelledTotal(List<String> lines) {
  final upi = lines.any(_upiContext.hasMatch);
  if (upi) {
    for (final line in lines) {
      if (!isAmountOnlyLine(line)) continue;
      final a = receiptAmountsIn(line).first;
      if (a.isNegative) continue;
      return (a.paise / 100, a.hasCurrency ? 0.8 : 0.6);
    }
  }
  final marked = <int>{
    for (final line in lines)
      if (_labelScore(line) != 0)
        for (final a in receiptAmountsIn(line))
          if (a.hasCurrency && !a.isNegative) a.paise,
  };
  if (marked.length == 1) return (marked.first / 100, 0.5);
  return null;
}
