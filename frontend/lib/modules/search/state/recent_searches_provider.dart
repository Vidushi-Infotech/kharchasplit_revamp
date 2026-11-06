import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/state/auth_provider.dart';

/// How many recent searches are remembered.
const maxRecentSearches = 8;

/// [query] moved to the front of [recent] (case-insensitive dedupe), capped
/// at [max]. Pure, for tests.
List<String> pushRecentSearch(
  List<String> recent,
  String query, {
  int max = maxRecentSearches,
}) {
  final q = query.trim();
  if (q.isEmpty) return recent;
  final lower = q.toLowerCase();
  return [
    q,
    ...recent.where((r) => r.toLowerCase() != lower),
  ].take(max).toList();
}

/// Last [maxRecentSearches] searches (newest first), in SharedPreferences
/// under the signed-in user's id — another account on the same phone never
/// sees them. Never synced; "Clear" wipes them.
final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );

class RecentSearchesNotifier extends Notifier<List<String>> {
  String? _prefsKey;

  @override
  List<String> build() {
    final userId = ref.watch(myIdProvider);
    _prefsKey = userId == null ? null : 'search.recent.$userId';
    _load();
    return const [];
  }

  Future<void> _load() async {
    final key = _prefsKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(key);
      if (saved != null && ref.mounted && key == _prefsKey) {
        state = saved.take(maxRecentSearches).toList();
      }
    } catch (_) {
      // Unreadable prefs: start with no recent searches.
    }
  }

  Future<void> add(String query) => _save(pushRecentSearch(state, query));

  Future<void> remove(String query) =>
      _save(state.where((r) => r != query).toList());

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> next) async {
    state = next;
    final key = _prefsKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, next);
    } catch (_) {
      // Non-fatal: the list still works for this session.
    }
  }
}
