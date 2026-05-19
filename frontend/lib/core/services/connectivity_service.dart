import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Tri-state connectivity. `unknown` is only used while we wait for the
/// first reading after app start; it's never re-emitted.
enum ConnectivityState { unknown, online, offline }

/// Owns one [Connectivity] subscription, emits a debounced
/// [ConnectivityState] stream, and exposes an on-demand HTTP probe for the
/// "wifi without internet" / captive-portal case.
///
/// Two distinct signals are tracked separately:
///   - **Network reachability** (synchronous, instant): does the OS report
///     any network interface? Drives the banner.
///   - **Internet reachability** (async, ~200ms): can we actually reach the
///     API? Used to confirm before we declare ourselves "back online" after
///     a request failure, and to recover from captive portals.
class ConnectivityService {
  ConnectivityService({
    Connectivity? plugin,
    http.Client? httpClient,
    Duration debounce = const Duration(milliseconds: 500),
    Duration probeTimeout = const Duration(seconds: 3),
    this.probeUrl = 'https://api.kharchasplit.com/health',
  })  : _plugin = plugin ?? Connectivity(),
        _http = httpClient ?? http.Client(),
        _debounce = debounce,
        _probeTimeout = probeTimeout;

  final Connectivity _plugin;
  final http.Client _http;
  final Duration _debounce;
  final Duration _probeTimeout;

  /// Endpoint used by the on-demand probe. Override in tests.
  final String probeUrl;

  /// Last emitted state. Useful for callers that want to act *now* without
  /// awaiting the next stream event (e.g. the Dio fast-fail interceptor).
  ConnectivityState _last = ConnectivityState.unknown;
  ConnectivityState get current => _last;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounceTimer;
  final _controller = StreamController<ConnectivityState>.broadcast();

  /// Broadcast stream of states. Subscribe to drive UI / providers.
  Stream<ConnectivityState> get stream => _controller.stream;

  /// Start listening. Idempotent.
  void start() {
    if (_sub != null) return;
    // Seed the first value immediately so listeners don't sit on `unknown`.
    _plugin.checkConnectivity().then((results) {
      _emit(_mapResults(results));
    }).catchError((_) {
      _emit(ConnectivityState.offline);
    });
    _sub = _plugin.onConnectivityChanged.listen(
      (results) => _scheduleEmit(_mapResults(results)),
      onError: (_) => _scheduleEmit(ConnectivityState.offline),
    );
  }

  /// Debounce rapid flips (e.g. wifi → cellular handoff fires two events
  /// in quick succession). 500 ms is plenty — slower than the OS's
  /// internal reconnect, faster than the user notices.
  void _scheduleEmit(ConnectivityState next) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _emit(next));
  }

  void _emit(ConnectivityState next) {
    if (next == _last) return;
    _last = next;
    _controller.add(next);
  }

  ConnectivityState _mapResults(List<ConnectivityResult> results) {
    // `none` is the only result that means "really nothing". Wifi /
    // mobile / ethernet / vpn / bluetooth all count as online (we let
    // the actual HTTP probe disambiguate captive portals).
    if (results.isEmpty) return ConnectivityState.offline;
    final allNone =
        results.every((r) => r == ConnectivityResult.none);
    return allNone ? ConnectivityState.offline : ConnectivityState.online;
  }

  /// Fires an HTTP HEAD/GET against [probeUrl]. Returns true only if we
  /// got a 2xx/3xx response within [_probeTimeout]. Used to confirm real
  /// internet after the OS says we're online but a request just failed.
  Future<bool> hasRealInternet() async {
    try {
      final resp = await _http
          .get(Uri.parse(probeUrl))
          .timeout(_probeTimeout);
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Connectivity] probe failed: $e');
      }
      return false;
    }
  }

  /// Force a re-read from the OS. Useful after a Dio connection error so
  /// the banner state self-corrects without waiting for an OS event.
  Future<void> recheck() async {
    try {
      final results = await _plugin.checkConnectivity();
      _emit(_mapResults(results));
    } catch (_) {/* ignore — next OS event will refresh */}
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
    _http.close();
  }
}
