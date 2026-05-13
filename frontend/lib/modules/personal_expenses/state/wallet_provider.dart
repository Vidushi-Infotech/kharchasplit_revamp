import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/wallet/wallet_local_store.dart';
import '../../../models/wallet_source_model.dart';
import '../../auth/state/auth_provider.dart';

class WalletState {
  const WalletState({
    required this.sources,
    required this.expenseSourceMap,
  });

  final List<WalletSource> sources;
  final Map<String, String> expenseSourceMap;

  static const empty = WalletState(sources: [], expenseSourceMap: {});

  double get totalAvailable =>
      sources.fold<double>(0, (sum, s) => sum + s.balance);

  WalletState copyWith({
    List<WalletSource>? sources,
    Map<String, String>? expenseSourceMap,
  }) =>
      WalletState(
        sources: sources ?? this.sources,
        expenseSourceMap: expenseSourceMap ?? this.expenseSourceMap,
      );
}

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);

class WalletNotifier extends AsyncNotifier<WalletState> {
  static const _uuid = Uuid();

  String? get _userId => ref.read(authProvider).user?.id;

  Future<WalletLocalStore> _store() =>
      ref.read(walletLocalStoreProvider.future);

  @override
  Future<WalletState> build() async {
    final userId = ref.watch(authProvider).user?.id;
    if (userId == null) return WalletState.empty;
    final store = await _store();
    final sources = await store.readSources(userId);
    final map = await store.readExpenseSourceMap(userId);
    return WalletState(sources: sources, expenseSourceMap: map);
  }

  Future<void> _persistSources(List<WalletSource> sources) async {
    final userId = _userId;
    if (userId == null) return;
    final store = await _store();
    await store.writeSources(userId, sources);
  }

  Future<void> _persistMap(Map<String, String> map) async {
    final userId = _userId;
    if (userId == null) return;
    final store = await _store();
    await store.writeExpenseSourceMap(userId, map);
  }

  // ─── Source CRUD ──────────────────────────────────────────────────────
  Future<void> addSource({
    required String name,
    required WalletSourceType type,
    required double balance,
  }) async {
    final current = state.value ?? WalletState.empty;
    final updated = [
      ...current.sources,
      WalletSource(
        id: _uuid.v4(),
        name: name.trim(),
        type: type,
        balance: balance,
      ),
    ];
    await _persistSources(updated);
    state = AsyncData(current.copyWith(sources: updated));
  }

  Future<void> editSource(
    String id, {
    String? name,
    double? balance,
  }) async {
    final current = state.value ?? WalletState.empty;
    final updated = current.sources.map((s) {
      if (s.id != id) return s;
      return s.copyWith(name: name, balance: balance);
    }).toList();
    await _persistSources(updated);
    state = AsyncData(current.copyWith(sources: updated));
  }

  /// Removes a source. Existing expense → source mappings to it are left as-is
  /// (they'll be ignored on refund attempts).
  Future<void> removeSource(String id) async {
    final current = state.value ?? WalletState.empty;
    final updated = current.sources.where((s) => s.id != id).toList();
    await _persistSources(updated);
    state = AsyncData(current.copyWith(sources: updated));
  }

  // ─── Deduct / refund (called by personalExpensesProvider) ─────────────
  Future<void> deductForExpense({
    required String sourceId,
    required String expenseId,
    required double amount,
  }) async {
    final current = state.value ?? WalletState.empty;
    final updatedSources = current.sources.map((s) {
      if (s.id != sourceId) return s;
      return s.copyWith(balance: s.balance - amount);
    }).toList();
    final updatedMap = {...current.expenseSourceMap, expenseId: sourceId};
    await _persistSources(updatedSources);
    await _persistMap(updatedMap);
    state = AsyncData(WalletState(
      sources: updatedSources,
      expenseSourceMap: updatedMap,
    ));
  }

  /// Refund the amount to whatever source originally paid. Silent no-op
  /// if the mapping or source is gone.
  Future<void> refundExpense({
    required String expenseId,
    required double amount,
  }) async {
    final current = state.value ?? WalletState.empty;
    final sourceId = current.expenseSourceMap[expenseId];
    if (sourceId == null) return;
    final hasSource = current.sources.any((s) => s.id == sourceId);
    final updatedMap = {...current.expenseSourceMap}..remove(expenseId);
    final updatedSources = hasSource
        ? current.sources.map((s) {
            if (s.id != sourceId) return s;
            return s.copyWith(balance: s.balance + amount);
          }).toList()
        : current.sources;
    await _persistSources(updatedSources);
    await _persistMap(updatedMap);
    state = AsyncData(WalletState(
      sources: updatedSources,
      expenseSourceMap: updatedMap,
    ));
  }
}
