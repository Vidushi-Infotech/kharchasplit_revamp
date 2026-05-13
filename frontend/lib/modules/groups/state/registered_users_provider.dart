/// Normalize an arbitrary phone string into the last 10 digits.
/// Used to match device-contact numbers against backend records regardless
/// of formatting (spaces, +91, parens, dashes).
String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}
