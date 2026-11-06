import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/fx/fx_repository.dart';

/// Which rate the Add expense form previews: 1 [from] in [to] on [date]
/// ('YYYY-MM-DD', never after today — the server uses today's rate for a
/// future-dated expense too).
typedef FxRateQuery = ({String from, String to, String date});

FxRateQuery fxRateQueryFor(String from, String to, DateTime date) {
  // The phone's calendar day (a fetched expense date arrives in UTC).
  final now = DateTime.now();
  final day = date.isAfter(now) ? now : date.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return (
    from: from,
    to: to,
    date: '${day.year}-${two(day.month)}-${two(day.day)}',
  );
}

/// The live rate for the "≈ ₹8,312.35 at 1 USD = ₹83.12" line. Keyed by
/// currency and date only — typing the amount never refetches (the
/// conversion itself is local). A short wait first debounces flipping
/// through currencies / dates; no automatic retries, so "rate unavailable"
/// (503 FX_UNAVAILABLE) shows at once and the user can enter one.
final fxRateProvider = FutureProvider.autoDispose.family<FxRate, FxRateQuery>((
  ref,
  q,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (!ref.mounted) throw const FxUnavailableException();
  final rate = await ref
      .read(fxRepositoryProvider)
      .rate(from: q.from, to: q.to, date: DateTime.parse(q.date));
  // Rates for a past day never change: keep it for the session.
  ref.keepAlive();
  return rate;
}, retry: (_, _) => null);
