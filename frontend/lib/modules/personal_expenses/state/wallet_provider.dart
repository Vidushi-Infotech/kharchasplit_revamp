import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/state/feature_flags_provider.dart';
import '../../../data/personal_accounts/personal_accounts_repository.dart';
import '../../../data/wallet/wallet_local_store.dart';
import '../../../models/personal_expense_model.dart';
import '../../../models/personal_transfer_model.dart';
import '../../../models/wallet_source_model.dart';
import '../../auth/state/auth_provider.dart';
import 'personal_expenses_provider.dart';

class WalletState {
  const WalletState({
    required this.sources,
    required this.expenseSourceMap,
    this.onServer = false,
  });

  final List<WalletSource> sources;
  final Map<String, String> expenseSourceMap;

  /// Server accounts (`personalAccounts` flag): balances are computed
  /// there, removing archives, and transfers are possible.
  final bool onServer;

  static const empty = WalletState(sources: [], expenseSourceMap: {});

  double get totalAvailable =>
      sources.fold<double>(0, (sum, s) => sum + s.balance);

  WalletState copyWith({
    List<WalletSource>? sources,
    Map<String, String>? expenseSourceMap,
  }) => WalletState(
    sources: sources ?? this.sources,
    expenseSourceMap: expenseSourceMap ?? this.expenseSourceMap,
    onServer: onServer,
  );
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, WalletState>(
  WalletNotifier.new,
);

class WalletNotifier extends AsyncNotifier<WalletState> {
  static const _uuid = Uuid();

  String? get _userId => ref.read(authProvider).user?.id;

  Future<WalletLocalStore> _store() =>
      ref.read(walletLocalStoreProvider.future);

  PersonalAccountsRepository get _server =>
      ref.read(personalAccountsRepositoryProvider);

  bool get _onServer => state.value?.onServer ?? false;

  @override
  Future<WalletState> build() async {
    final userId = ref.watch(myIdProvider);
    if (userId == null) return WalletState.empty;
    final store = await _store();
    final flags = await ref.watch(featureFlagsProvider.future);
    if (!flags.contains('personalAccounts')) {
      final sources = await store.readSources(userId);
      final map = await store.readExpenseSourceMap(userId);
      return WalletState(sources: sources, expenseSourceMap: map);
    }

    // Server accounts. Balances follow the entries, so re-fetch with them.
    final entries = ref.watch(personalExpensesProvider.select((s) => s.value));
    final sources = await _serverSources(userId, store);
    return WalletState(
      sources: sources,
      expenseSourceMap: {
        for (final PersonalExpenseModel e in entries ?? const [])
          if (e.accountId != null) e.id: e.accountId!,
      },
      onServer: true,
    );
  }

  /// The server's accounts, moving this phone's wallet there the first
  /// time (the server does it at most once per user).
  Future<List<WalletSource>> _serverSources(
    String userId,
    WalletLocalStore store,
  ) async {
    if (!store.isImported(userId)) {
      final local = await store.readSources(userId);
      if (local.isNotEmpty) {
        final links = await store.readExpenseSourceMap(userId);
        final sources = await _server.importLocal(local, links);
        await store.markImported(userId);
        return sources;
      }
      await store.markImported(userId);
    }
    return _server.list();
  }

  /// After a server change: fetch the accounts again.
  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
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
    if (_onServer) {
      await _server.create(name: name.trim(), type: type, balance: balance);
      return _reload();
    }
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

  Future<void> editSource(String id, {String? name, double? balance}) async {
    if (_onServer) {
      await _server.update(id, name: name?.trim(), balance: balance);
      return _reload();
    }
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
    // On the server this archives the account: its entries keep it.
    if (_onServer) {
      await _server.archive(id);
      return _reload();
    }
    final current = state.value ?? WalletState.empty;
    final updated = current.sources.where((s) => s.id != id).toList();
    await _persistSources(updated);
    state = AsyncData(current.copyWith(sources: updated));
  }

  // ─── Deduct / refund (called by personalExpensesProvider) ─────────────
  /// Takes [amount] out of the source; a negative amount (income) adds it.
  Future<void> deductForExpense({
    required String sourceId,
    required String expenseId,
    required double amount,
  }) async {
    // The server already counted it (the entry was saved with its account).
    if (_onServer) return _reload();
    final current = state.value ?? WalletState.empty;
    final updatedSources = current.sources.map((s) {
      if (s.id != sourceId) return s;
      return s.copyWith(balance: s.balance - amount);
    }).toList();
    final updatedMap = {...current.expenseSourceMap, expenseId: sourceId};
    await _persistSources(updatedSources);
    await _persistMap(updatedMap);
    state = AsyncData(
      WalletState(sources: updatedSources, expenseSourceMap: updatedMap),
    );
  }

  /// Put [amount] back into whatever source the entry used (negative for an
  /// income, which takes it out again). Silent no-op if the mapping or
  /// source is gone.
  Future<void> refundExpense({
    required String expenseId,
    required double amount,
  }) async {
    if (_onServer) return _reload();
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
    state = AsyncData(
      WalletState(sources: updatedSources, expenseSourceMap: updatedMap),
    );
  }

  // ─── Transfers (server accounts only) ─────────────────────────────────
  Future<void> transfer({
    required String fromId,
    required String toId,
    required double amount,
    String? note,
  }) async {
    await _server.transfer(
      fromAccountId: fromId,
      toAccountId: toId,
      amount: amount,
      note: note,
    );
    ref.invalidate(accountTransfersProvider);
    return _reload();
  }

  Future<void> deleteTransfer(String id) async {
    await _server.deleteTransfer(id);
    ref.invalidate(accountTransfersProvider);
    return _reload();
  }
}

/// Transfers in and out of one account (null: all), newest first.
final accountTransfersProvider = FutureProvider.autoDispose
    .family<List<PersonalTransfer>, String?>(
      (ref, accountId) => ref
          .read(personalAccountsRepositoryProvider)
          .transfers(accountId: accountId),
    );
