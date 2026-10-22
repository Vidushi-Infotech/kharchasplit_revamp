/// Calendar dates from the API (an expense's date) — a day, not an instant.
///
/// The server stores them as DATE in India time and the database driver
/// sends them as that day's midnight IST in UTC ("2026-10-21T18:30:00Z" for
/// 22 Oct). Parsing that as an instant shows the wrong day on a phone set to
/// any other time zone, so read the India calendar day back out and keep it
/// as a local date.
DateTime? parseServerCalendarDate(String raw) {
  final plain = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (plain != null) {
    return DateTime(
      int.parse(plain[1]!),
      int.parse(plain[2]!),
      int.parse(plain[3]!),
    );
  }
  final instant = DateTime.tryParse(raw);
  if (instant == null) return null;
  final ist = instant.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(ist.year, ist.month, ist.day);
}
