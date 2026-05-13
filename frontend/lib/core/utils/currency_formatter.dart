import 'package:intl/intl.dart';

/// Currency formatting utility
/// Handles multiple currencies with proper formatting
class CurrencyFormatter {
  /// Format amount as currency with symbol
  /// Supports Indian numbering system (₹1,00,000.00)
  static String format(
    double amount, {
    String currency = '₹',
    bool showSign = false,
    int decimalPlaces = 2,
  }) {
    final absAmount = amount.abs();

    // Indian Rupee uses different formatting
    if (currency == '₹') {
      final formatted = _formatIndianCurrency(absAmount, decimalPlaces);
      if (showSign) {
        return amount >= 0 ? '+$currency$formatted' : '-$currency$formatted';
      }
      return '$currency$formatted';
    }

    // Other currencies use standard international format
    final formatter = NumberFormat.currency(
      locale: _getCurrencyLocale(currency),
      symbol: currency,
      decimalDigits: decimalPlaces,
    );

    final formatted = formatter.format(absAmount);
    if (showSign) {
      return amount >= 0 ? '+$formatted' : '-$formatted';
    }
    return formatted;
  }

  /// Format Indian currency with proper comma placement
  /// 100000 → 1,00,000.00
  static String _formatIndianCurrency(double amount, int decimalPlaces) {
    final parts = amount.toStringAsFixed(decimalPlaces).split('.');
    String integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    // Add commas in Indian format (from right: 2, 2, 2...)
    final reversed = integerPart.split('').reversed.join();
    final chunks = <String>[];

    for (int i = 0; i < reversed.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) {
        chunks.add(',');
      }
      chunks.add(reversed[i]);
    }

    final formatted = chunks.reversed.join();
    return '$formatted.$decimalPart';
  }

  /// Get locale for currency formatting
  static String _getCurrencyLocale(String currency) {
    switch (currency) {
      case '\$':
      case 'USD':
        return 'en_US';
      case '€':
      case 'EUR':
        return 'en_IE';
      case '£':
      case 'GBP':
        return 'en_GB';
      case '₹':
      case 'INR':
        return 'en_IN';
      default:
        return 'en_US';
    }
  }

  /// Parse currency string to double
  /// "₹1,00,000.50" → 100000.50
  static double? parse(String value) {
    try {
      // Remove currency symbol and spaces
      String cleaned = value.replaceAll(RegExp(r'[₹$€£\s]'), '');
      // Remove commas
      cleaned = cleaned.replaceAll(',', '');
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Format for display in cards/tiles (compact format)
  /// 100000 → ₹1L (for large amounts)
  static String compact(double amount, {String currency = '₹'}) {
    if (amount.abs() >= 10000000) {
      // > 1 crore
      return '${currency}${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount.abs() >= 100000) {
      // > 1 lakh
      return '${currency}${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount.abs() >= 1000) {
      // > 1000
      return '${currency}${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, currency: currency);
  }

  /// Get color indicator for amount (green for positive, orange for negative)
  static String getSignPrefix(double amount) {
    if (amount > 0) {
      return '+';
    } else if (amount < 0) {
      return '-';
    }
    return '';
  }
}
