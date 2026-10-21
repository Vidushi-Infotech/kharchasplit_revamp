import 'dart:convert';

/// Which GET responses are kept for offline use, and under which key.
///
/// Pure Dart (no Dio / Hive) so the rules are unit-testable.
///
/// Only read-only screens the app needs while offline are cached: groups,
/// expenses, payments, the dashboard, friends, the own profile, recurring
/// rules and the app-version check. Auth, notifications, exports,
/// payment-info, reports and lookups are never stored.
abstract final class CachePolicy {
  /// Hard cap on entries in the cache box; the oldest go first.
  static const maxEntries = 300;

  /// A single response bigger than this (an expense with a large receipt
  /// photo, say) is not worth the disk — it is simply not cached.
  static const maxEntryChars = 2 * 1024 * 1024;

  // Fixed words that sit where an id would in `/expenses/:id` etc. — those
  // routes are not reads of a single record and must not match.
  static const _reservedSegments = {
    'category-suggestion',
    'lookup-by-phone',
    'by-phone',
  };

  static final _groupsList = RegExp(r'^/groups$');
  static final _groupById = RegExp(r'^/groups/([^/]+)$');
  static final _groupRecurring = RegExp(r'^/groups/([^/]+)/recurring$');
  static final _expensesList = RegExp(r'^/expenses$');
  static final _expenseById = RegExp(r'^/expenses/([^/]+)$');
  static final _settlementsList = RegExp(r'^/settlements$');
  static final _appVersion = RegExp(r'^/app-version$');
  // `/users/:id`, `/users/:id/dashboard`, `/users/:id/friends` — only for
  // the signed-in user's own id (see [isCacheable]).
  static final _ownUser = RegExp(r'^/users/([^/]+)(?:/(dashboard|friends))?$');

  /// True when a GET to [path] (no query string, leading `/`) may be cached
  /// for [userId].
  static bool isCacheable(String path, {required String userId}) {
    final p = _normalise(path);
    if (p == null || userId.isEmpty) return false;
    if (_groupsList.hasMatch(p) ||
        _expensesList.hasMatch(p) ||
        _settlementsList.hasMatch(p) ||
        _appVersion.hasMatch(p)) {
      return true;
    }
    final id = (_groupById.firstMatch(p) ??
            _groupRecurring.firstMatch(p) ??
            _expenseById.firstMatch(p))
        ?.group(1);
    if (id != null) return !_reservedSegments.contains(id);
    final user = _ownUser.firstMatch(p);
    return user != null && user.group(1) == userId;
  }

  /// Cache key for a request, or null when it must not be cached.
  ///
  /// The key starts with the signed-in user's id, so another account on the
  /// same device never reads this one's data — even if the sign-out wipe
  /// didn't run. The query string is part of the key (sorted, so the order
  /// callers pass parameters in doesn't matter): page 2 of a list is a
  /// different entry from page 1.
  static String? keyFor({
    required String? userId,
    required String path,
    Map<String, dynamic> queryParameters = const {},
  }) {
    if (userId == null || userId.isEmpty) return null;
    final uri = Uri.tryParse(path);
    // Absolute URLs point somewhere other than our API base — never cached.
    if (uri == null || uri.hasScheme) return null;
    final cleanPath = _normalise(uri.path);
    if (cleanPath == null || !isCacheable(cleanPath, userId: userId)) {
      return null;
    }
    final query = <String, String>{
      ...uri.queryParameters,
      for (final e in queryParameters.entries)
        if (e.value != null)
          e.key: e.value is Iterable
              ? (e.value as Iterable).join(',')
              : e.value.toString(),
    };
    final sorted = query.keys.toList()..sort();
    final qs = sorted
        .map((k) =>
            '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(query[k]!)}')
        .join('&');
    return qs.isEmpty ? '$userId|$cleanPath' : '$userId|$cleanPath?$qs';
  }

  /// Keys to delete so at most [max] entries remain, oldest [savedAt] first.
  static List<String> keysToEvict(Map<String, int> savedAtByKey, {int? max}) {
    final limit = max ?? maxEntries;
    final excess = savedAtByKey.length - limit;
    if (excess <= 0) return const [];
    final byAge = savedAtByKey.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return byAge.take(excess).map((e) => e.key).toList();
  }

  // `savedAt` is written first in every entry, so eviction can read it from
  // the start of the string without decoding a possibly large payload.
  static final _savedAtPrefix = RegExp(r'^\{"savedAt":(\d+)');

  /// The `savedAt` (ms since epoch) of a stored entry, or 0 if unreadable.
  static int savedAtOf(String raw) {
    final m = _savedAtPrefix.firstMatch(raw);
    if (m != null) return int.parse(m.group(1)!);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['savedAt'] is int) {
        return decoded['savedAt'] as int;
      }
    } catch (_) {/* corrupt entry — treated as oldest */}
    return 0;
  }

  static String? _normalise(String path) {
    if (!path.startsWith('/')) return null;
    return path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
  }
}
