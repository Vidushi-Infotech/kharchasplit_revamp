import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Currencies the user picked lately (ISO codes, most recent first), shown
/// right under the group's currency in the picker. Kept on the device.
class CurrencyRecents extends Notifier<List<String>> {
  static const _key = 'expense_recent_currencies';
  static const _max = 5;

  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getStringList(_key);
      if (saved != null && ref.mounted) state = saved;
    } catch (_) {
      // No storage (tests, private web window): just no recents.
    }
  }

  Future<void> use(String code) async {
    state = [code, ...state.where((c) => c != code)].take(_max).toList();
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, state);
    } catch (_) {}
  }
}

final currencyRecentsProvider = NotifierProvider<CurrencyRecents, List<String>>(
  CurrencyRecents.new,
);
