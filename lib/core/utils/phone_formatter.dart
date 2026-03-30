/// Phone number utilities for formatting and normalization
class PhoneFormatter {
  /// Normalize phone number to 10-digit format (Indian format)
  /// Removes country codes and formatting
  /// Example: "+91 98765 43210" -> "9876543210"
  static String normalizePhone(String phoneNumber) {
    // Remove all non-digit characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Remove country code +91 (12 digits total)
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return cleaned.substring(2);
    }

    // Remove leading 0 (11 digits total)
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      return cleaned.substring(1);
    }

    return cleaned;
  }

  /// Format phone number for display
  /// Example: "9876543210" -> "+91 98765 43210"
  static String formatPhoneForDisplay(String phoneNumber) {
    final normalized = normalizePhone(phoneNumber);

    if (normalized.length != 10) {
      return phoneNumber; // Return original if not 10 digits
    }

    return '+91 ${normalized.substring(0, 5)} ${normalized.substring(5)}';
  }

  /// Check if phone number is valid (10 digits after normalization)
  static bool isValidPhone(String phoneNumber) {
    final normalized = normalizePhone(phoneNumber);
    return normalized.length == 10 && int.tryParse(normalized) != null;
  }
}
