import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/utils/server_date.dart';

void main() {
  test('midnight IST sent as UTC is the India calendar day', () {
    expect(parseServerCalendarDate('2026-10-21T18:30:00.000Z'),
        DateTime(2026, 10, 22));
  });

  test('a plain date stays that date', () {
    expect(parseServerCalendarDate('2026-10-22'), DateTime(2026, 10, 22));
  });

  test('garbage is null', () {
    expect(parseServerCalendarDate('soon'), isNull);
  });
}
