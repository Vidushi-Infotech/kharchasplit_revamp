/// Currencies an expense can be entered in (`currencyConversion` flag).
///
/// Exactly the ones the server can convert: its rates come from Frankfurter
/// (European Central Bank reference rates), whose /currencies list is these
/// 30 (checked Oct 2026). Common trip currencies that ECB does NOT publish
/// — AED, SAR, QAR, LKR, NPR, BDT, VND, MVR — are left out on purpose:
/// offering them would only ever end in "rate unavailable".
class CurrencyInfo {
  const CurrencyInfo(this.code, this.name, this.symbol);

  /// ISO 4217, e.g. "USD".
  final String code;
  final String name;

  /// Shown before amounts. Unambiguous: "A$" not "$" for Australia; the
  /// code itself where several currencies share a sign (kr, Fr).
  final String symbol;
}

class CurrencyCatalog {
  CurrencyCatalog._();

  /// Most-used first (Indian travellers), then the rest A–Z. The picker
  /// shows the group's currency and recently used ones above this.
  static const all = <CurrencyInfo>[
    CurrencyInfo('INR', 'Indian Rupee', '₹'),
    CurrencyInfo('USD', 'US Dollar', r'$'),
    CurrencyInfo('EUR', 'Euro', '€'),
    CurrencyInfo('GBP', 'British Pound', '£'),
    CurrencyInfo('SGD', 'Singapore Dollar', r'S$'),
    CurrencyInfo('THB', 'Thai Baht', '฿'),
    CurrencyInfo('MYR', 'Malaysian Ringgit', 'RM'),
    CurrencyInfo('IDR', 'Indonesian Rupiah', 'Rp'),
    CurrencyInfo('JPY', 'Japanese Yen', '¥'),
    CurrencyInfo('AUD', 'Australian Dollar', r'A$'),
    CurrencyInfo('CAD', 'Canadian Dollar', r'C$'),
    CurrencyInfo('CHF', 'Swiss Franc', 'CHF'),
    CurrencyInfo('HKD', 'Hong Kong Dollar', r'HK$'),
    CurrencyInfo('NZD', 'New Zealand Dollar', r'NZ$'),
    CurrencyInfo('BRL', 'Brazilian Real', r'R$'),
    CurrencyInfo('CNY', 'Chinese Yuan', 'CN¥'),
    CurrencyInfo('CZK', 'Czech Koruna', 'Kč'),
    CurrencyInfo('DKK', 'Danish Krone', 'DKK'),
    CurrencyInfo('HUF', 'Hungarian Forint', 'Ft'),
    CurrencyInfo('ILS', 'Israeli Shekel', '₪'),
    CurrencyInfo('ISK', 'Icelandic Króna', 'ISK'),
    CurrencyInfo('KRW', 'South Korean Won', '₩'),
    CurrencyInfo('MXN', 'Mexican Peso', r'MX$'),
    CurrencyInfo('NOK', 'Norwegian Krone', 'NOK'),
    CurrencyInfo('PHP', 'Philippine Peso', '₱'),
    CurrencyInfo('PLN', 'Polish Złoty', 'zł'),
    CurrencyInfo('RON', 'Romanian Leu', 'lei'),
    CurrencyInfo('SEK', 'Swedish Krona', 'SEK'),
    CurrencyInfo('TRY', 'Turkish Lira', '₺'),
    CurrencyInfo('ZAR', 'South African Rand', 'R'),
  ];

  static CurrencyInfo? byCode(String? code) {
    if (code == null) return null;
    final c = code.toUpperCase();
    for (final info in all) {
      if (info.code == c) return info;
    }
    return null;
  }

  /// Symbol for [code], or the code itself for one not in the list (a
  /// group in, say, AED still shows "AED").
  static String symbolFor(String code) => byCode(code)?.symbol ?? code;

  /// The picker's order: [groupCode] first, then [recent] (most recent
  /// first), then [all]. Each code once; unknown recents dropped.
  static List<CurrencyInfo> pickerOrder(String groupCode, List<String> recent) {
    final seen = <String>{};
    final out = <CurrencyInfo>[];
    void add(CurrencyInfo info) {
      if (seen.add(info.code)) out.add(info);
    }

    add(byCode(groupCode) ?? CurrencyInfo(groupCode, groupCode, groupCode));
    for (final code in recent) {
      final info = byCode(code);
      if (info != null) add(info);
    }
    all.forEach(add);
    return out;
  }
}
