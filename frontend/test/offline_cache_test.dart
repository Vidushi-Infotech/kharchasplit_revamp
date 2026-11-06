import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/network/cache_policy.dart';
import 'package:kharchasplit/core/state/offline_data.dart';

void main() {
  test('only read-only screens are cached, own user only', () {
    for (final p in ['/groups', '/groups/g1', '/groups/g1/recurring', '/expenses', '/expenses/e1',
      '/settlements', '/app-version', '/users/me', '/users/me/dashboard', '/users/me/friends']) {
      expect(CachePolicy.isCacheable(p, userId: 'me'), isTrue, reason: p);
    }
    for (final p in ['/auth/login', '/users/other/dashboard', '/users/me/notifications',
      '/expenses/category-suggestion', '/groups/g1/export', '/users/u/payment-info']) {
      expect(CachePolicy.isCacheable(p, userId: 'me'), isFalse, reason: p);
    }
  });

  test('keys are per user and ignore query order', () {
    final a = CachePolicy.keyFor(userId: 'u1', path: '/expenses', queryParameters: {'groupId': 'g', 'page': 2});
    final b = CachePolicy.keyFor(userId: 'u1', path: '/expenses?page=2&groupId=g');
    expect(a, b);
    expect(CachePolicy.keyFor(userId: 'u2', path: '/expenses?page=2&groupId=g'), isNot(a));
    expect(CachePolicy.keyFor(userId: null, path: '/groups'), isNull);
  });

  test('evicts the oldest beyond the cap', () {
    expect(CachePolicy.keysToEvict({'a': 3, 'b': 1, 'c': 2}, max: 1), ['b', 'c']);
    expect(CachePolicy.savedAtOf('{"savedAt":42,"data":{}}'), 42);
  });

  test('"ago" text', () {
    final now = DateTime(2026, 10, 21, 12);
    expect(formatAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(formatAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(formatAgo(now.subtract(const Duration(hours: 2)), now: now), '2h ago');
    expect(formatAgo(now.subtract(const Duration(days: 1, hours: 2)), now: now), 'yesterday');
    expect(formatAgo(now.subtract(const Duration(days: 3)), now: now), '3 days ago');
  });
}
