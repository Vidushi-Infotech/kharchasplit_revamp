/// Low-level pieces of the receipt parser (receipt_scan_parser.dart): money
/// amounts, dates and the merchant name in OCR text. Pure Dart, no Flutter —
/// unit-tested with real-looking Indian receipts.
library;

/// A money amount found in one OCR line.
class ReceiptAmount {
  const ReceiptAmount(
    this.paise, {
    required this.hasCurrency,
    required this.hasDecimals,
    required this.isNegative,
  });

  final int paise;

  /// Written with ₹ / Rs / INR in front of it.
  final bool hasCurrency;

  /// Written with paise ("450.00"), not just rupees.
  final bool hasDecimals;

  /// "-₹100" (discounts, round-off) — never a total.
  final bool isNegative;
}

// Times, percentages, dates and long digit runs (phone numbers, bill /
// transaction ids) are blanked out before looking for amounts.
final _time = RegExp(
  r'\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:am|pm)?\b',
  caseSensitive: false,
);
final _percent = RegExp(r'\d+(?:\.\d+)?\s*%');
final _numericDate = RegExp(r'\b\d{1,4}[/\-.]\d{1,2}[/\-.]\d{2,4}\b');
final _longDigits = RegExp(r'\d{8,}');
final _currencyBefore = RegExp(
  r'(?:₹|\brs\b\.?|\binr\b)\s*[:.]?\s*-?\s*$',
  caseSensitive: false,
);
final _number = RegExp(r'\d[\d,]*(?:\.\d+)?');
final _indianGrouping = RegExp(r'^\d{1,2}(?:,\d{2})*,\d{3}$');
final _westernGrouping = RegExp(r'^\d{1,3}(?:,\d{3})+$');
final _decimalComma = RegExp(r'^\d+,\d{2}$');

/// OCR clean-up of one line before amounts are read: "1, 234.0O" →
/// "1,234.00", "Rs.1234/-" → "Rs.1234".
String normalizeReceiptLine(String line) {
  return line
      .replaceAllMapped(RegExp(r'(?<=\d)[Oo](?=\d|\b)'), (_) => '0')
      .replaceAllMapped(
        RegExp(r'(\d)\s*,\s*(\d{2,3})(?!\d)'),
        (m) => '${m[1]},${m[2]}',
      )
      .replaceAllMapped(
        RegExp(r'(\d)\s+\.\s*(\d{2})(?!\d)'),
        (m) => '${m[1]}.${m[2]}',
      )
      .replaceAll('/-', '')
      .replaceAll('\u20B9', '₹');
}

/// Every money amount in [line], left to right.
List<ReceiptAmount> receiptAmountsIn(String line) {
  var text = normalizeReceiptLine(line);
  for (final pattern in [_time, _percent, _numericDate, _longDigits]) {
    text = text.replaceAllMapped(pattern, (m) => ' ' * m[0]!.length);
  }
  final out = <ReceiptAmount>[];
  for (final m in _number.allMatches(text)) {
    final paise = _parsePaise(m[0]!);
    if (paise == null || paise <= 0) continue;
    final before = text.substring(0, m.start);
    final hasCurrency = _currencyBefore.hasMatch(before);
    final trimmed = before.trimRight();
    final isNegative =
        trimmed.endsWith('-') ||
        (hasCurrency &&
            RegExp(
              r'-\s*(?:₹|rs\.?|inr)\s*[:.]?\s*$',
              caseSensitive: false,
            ).hasMatch(before));
    out.add(
      ReceiptAmount(
        paise,
        hasCurrency: hasCurrency,
        hasDecimals: m[0]!.contains('.') || _decimalComma.hasMatch(m[0]!),
        isNegative: isNegative,
      ),
    );
  }
  return out;
}

/// "1,23,456.50" / "1234" / "1234,50" → paise; null when it isn't a
/// plausible amount (bad grouping, 3+ decimals like a fuel rate or volume,
/// more than ₹1 crore).
int? _parsePaise(String raw) {
  var token = raw.replaceAll(RegExp(r',+$'), '');
  var decimals = '';
  if (token.contains('.')) {
    final parts = token.split('.');
    if (parts.length != 2 || parts[1].length > 2) return null;
    token = parts[0];
    decimals = parts[1];
  } else if (_decimalComma.hasMatch(token)) {
    final parts = token.split(',');
    token = parts[0];
    decimals = parts[1];
  }
  if (token.contains(',')) {
    if (!_indianGrouping.hasMatch(token) && !_westernGrouping.hasMatch(token)) {
      return null;
    }
    token = token.replaceAll(',', '');
  }
  if (token.isEmpty || token.length > 8) return null;
  final rupees = int.tryParse(token);
  if (rupees == null) return null;
  final paise = rupees * 100 + int.parse(decimals.padRight(2, '0'));
  return paise > 1000000000 ? null : paise;
}

/// Whether [line] holds nothing but an amount (and maybe ₹ / Rs / ":").
bool isAmountOnlyLine(String line) {
  if (receiptAmountsIn(line).length != 1) return false;
  final rest = normalizeReceiptLine(line)
      .toLowerCase()
      .replaceAll(RegExp(r'\brs\b|\binr\b|₹'), '')
      .replaceAll(RegExp(r'[\d,.\s:\-*=]'), '');
  return rest.isEmpty;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

int? _month(String word) {
  final w = word.toLowerCase();
  if (w.length < 3) return null;
  final m = _months[w.substring(0, 3)];
  // "Sept", "October" are fine; "Octopus" is not a month.
  if (m == null) return null;
  const full = [
    'january', 'february', 'march', 'april', 'may', 'june', 'july', //
    'august', 'september', 'october', 'november', 'december',
  ];
  return full[m - 1].startsWith(w) || w == 'sept' ? m : null;
}

final _dmy = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b');
final _ymd = RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b');
final _dMonY = RegExp(
  r"\b(\d{1,2})(?:st|nd|rd|th)?[\s\-/.,]*([A-Za-z]{3,9})\.?[\s\-/.,']*(\d{4}|\d{2})\b",
);
final _monDY = RegExp(
  r'\b([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
);
final _dMon = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,9})\b(?!\s*\d)');

/// The bill date in [lines], or null. Day-first (Indian) numeric dates; a
/// month-first one only when day-first can't be a date. Never in the
/// future and not more than 5 years back. Lines that say "date" win.
DateTime? parseReceiptDate(List<String> lines, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  DateTime? valid(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    if (date.month != m || date.day != d) return null; // 31/02
    if (date.isAfter(day)) return null;
    if (date.isBefore(DateTime(day.year - 5, day.month, day.day))) return null;
    return date;
  }

  DateTime? inLine(String line, {required bool allowNoYear}) {
    for (final m in _ymd.allMatches(line)) {
      final d = valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      if (d != null) return d;
    }
    for (final m in _dmy.allMatches(line)) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!), y = int.parse(m[3]!);
      final d = b <= 12 ? valid(y, b, a) : valid(y, a, b);
      if (d != null) return d;
    }
    for (final m in _dMonY.allMatches(line)) {
      final month = _month(m[2]!);
      if (month == null) continue;
      final d = valid(int.parse(m[3]!), month, int.parse(m[1]!));
      if (d != null) return d;
    }
    for (final m in _monDY.allMatches(line)) {
      final month = _month(m[1]!);
      if (month == null) continue;
      final d = valid(int.parse(m[3]!), month, int.parse(m[2]!));
      if (d != null) return d;
    }
    if (allowNoYear) {
      // "16 Oct, 8:42 pm" (UPI apps leave out the current year).
      for (final m in _dMon.allMatches(line)) {
        final month = _month(m[2]!);
        if (month == null) continue;
        final d = int.parse(m[1]!);
        final date = valid(day.year, month, d) ?? valid(day.year - 1, month, d);
        if (date != null) return date;
      }
    }
    return null;
  }

  final labelled = RegExp(r'\b(date|dt|dated)\b', caseSensitive: false);
  for (final line in lines.where(labelled.hasMatch)) {
    final d = inLine(line, allowNoYear: false);
    if (d != null) return d;
  }
  for (final allowNoYear in [false, true]) {
    for (final line in lines) {
      final d = inLine(line, allowNoYear: allowNoYear);
      if (d != null) return d;
    }
  }
  return null;
}

// Lines that are never the merchant: tax ids, contacts, headers, UPI
// screen labels.
final _notMerchant = RegExp(
  r'\b(gstin|gst|fssai|cin|pan|tin|phone|ph|mob|mobile|tel|email|e-mail|www|'
  r'invoice|receipt|bill|cash memo|original|duplicate|copy|welcome|thank|'
  r'thanks|order summary|order details|order id|order|token|table|kot|'
  r'cashier|date|time|upi|transaction|completed|successful|payment|'
  r'google pay|gpay|phonepe|paytm|bhim|customer|cust|guest|server|steward|'
  r'delivered|banking name|total|amount)\b|http|\.com|@',
  caseSensitive: false,
);

final _addressWord = RegExp(
  r'\b(road|rd|street|st|nagar|floor|near|opp|opposite|sector|marg|lane|'
  r'colony|layout|main|cross|plot|shop no|bldg|building|complex|highway|nh|'
  r'pin|dist|district|taluk|village|block|phase|tower|stage)\b',
  caseSensitive: false,
);

/// The shop / restaurant / person paid, or null. "Paid to X" and "order
/// from X" win; otherwise the first line near the top that is a name — not
/// a GSTIN, phone, address, header ("TAX INVOICE") or amount. ALL CAPS
/// names come back in Title Case.
String? parseReceiptMerchant(List<String> lines) {
  final paidTo = RegExp(
    r'^(?:paid to|paying|your order from|order from|to(?!\s*pay))\b\s*:?\s*(.*)$',
    caseSensitive: false,
  );
  for (var i = 0; i < lines.length; i++) {
    final m = paidTo.firstMatch(lines[i].trim());
    if (m == null) continue;
    var name = m[1]!.trim();
    if (name.isEmpty && i + 1 < lines.length) name = lines[i + 1].trim();
    if (_looksLikeName(name)) return _tidyName(name);
  }
  for (final line in lines.take(8)) {
    if (_looksLikeName(line)) return _tidyName(line);
  }
  return null;
}

bool _looksLikeName(String raw) {
  final line = raw.trim();
  if (line.length < 3 || line.length > 48) return false;
  if (_notMerchant.hasMatch(line)) return false;
  if (_addressWord.hasMatch(line)) return false;
  if (RegExp(r'\d').allMatches(line).length >= 3) return false;
  if (receiptAmountsIn(line).isNotEmpty && RegExp(r'[₹]').hasMatch(line)) {
    return false;
  }
  final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
  return letters >= 3 && letters >= line.replaceAll(' ', '').length * 0.6;
}

String _tidyName(String raw) {
  final name = raw
      .trim()
      .replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9).]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (name != name.toUpperCase()) return name;
  return name
      .split(' ')
      .map((w) => w.length <= 1 ? w : '${w[0]}${w.substring(1).toLowerCase()}')
      .join(' ');
}
