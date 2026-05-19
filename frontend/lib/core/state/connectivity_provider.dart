import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';

/// Owns the live [ConnectivityService] for the app. The service starts
/// listening the first time the provider is read.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  service.start();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of [ConnectivityState] values. UI watches this.
///
/// Emits the current value on subscription (no `loading` state for the
/// banner) because [ConnectivityService] seeds `current` synchronously.
final connectivityProvider = StreamProvider<ConnectivityState>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  // Seed with the latest known value so a fresh subscriber doesn't sit on
  // AsyncLoading for the first event.
  return service.stream.distinct().asBroadcastStream(
        onListen: (sub) {
          // No-op — startup emission happens in ConnectivityService.start().
        },
      );
});

/// Convenience boolean. Treated as `false` while connectivity is unknown,
/// so the offline banner doesn't flash on cold start before the first read.
final isOfflineProvider = Provider<bool>((ref) {
  final state = ref.watch(connectivityProvider).whenOrNull(data: (s) => s) ??
      ref.read(connectivityServiceProvider).current;
  return state == ConnectivityState.offline;
});

/// Fires `void` events whenever connectivity transitions from offline to
/// online. Use this with `ref.listen` to refresh stale data after a
/// reconnection (dashboard, groups, notifications inbox, etc.).
///
/// Implemented as a StreamProvider so subscribers don't wake up for any
/// other state change.
final onReconnectStreamProvider = StreamProvider<void>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  ConnectivityState last = service.current;
  return service.stream
      .where((next) {
        final reconnected =
            last != ConnectivityState.online && next == ConnectivityState.online;
        last = next;
        return reconnected;
      })
      .map<void>((_) {});
});
