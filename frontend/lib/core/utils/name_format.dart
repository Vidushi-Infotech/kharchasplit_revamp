/// Short display names for dense lists: "Test Receiver" → "Test R.".
abstract final class NameFormat {
  /// First name plus the first letter of the last word. One-word names
  /// and blank names come back unchanged (trimmed).
  static String short(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.last.isEmpty) return name.trim();
    return '${parts.first} ${parts.last[0].toUpperCase()}.';
  }
}
