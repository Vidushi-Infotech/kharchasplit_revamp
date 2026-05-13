import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/wallet_source_model.dart';

/// Per-user local store for wallet sources and the (expenseId → sourceId) map.
/// Lives in SharedPreferences. Not synced to backend.
class WalletLocalStore {
  WalletLocalStore(this._prefs);
  final SharedPreferences _prefs;

  String _sourcesKey(String userId) => 'wallet:sources:$userId';
  String _expenseMapKey(String userId) => 'wallet:expense_source_map:$userId';

  Future<List<WalletSource>> readSources(String userId) async {
    final raw = _prefs.getString(_sourcesKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WalletSource.fromJson)
        .toList();
  }

  Future<void> writeSources(String userId, List<WalletSource> sources) async {
    final encoded = jsonEncode(sources.map((s) => s.toJson()).toList());
    await _prefs.setString(_sourcesKey(userId), encoded);
  }

  Future<Map<String, String>> readExpenseSourceMap(String userId) async {
    final raw = _prefs.getString(_expenseMapKey(userId));
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> writeExpenseSourceMap(
      String userId, Map<String, String> map) async {
    await _prefs.setString(_expenseMapKey(userId), jsonEncode(map));
  }

  /// Wipe everything (use on logout).
  Future<void> clear(String userId) async {
    await _prefs.remove(_sourcesKey(userId));
    await _prefs.remove(_expenseMapKey(userId));
  }
}

/// Async because SharedPreferences.getInstance() is async — wrapped in a
/// FutureProvider so callers always get a ready-to-use store.
final walletLocalStoreProvider = FutureProvider<WalletLocalStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return WalletLocalStore(prefs);
});
