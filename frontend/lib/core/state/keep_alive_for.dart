import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bounded cache for `autoDispose` providers.
///
/// Riverpod's `autoDispose` drops state the moment the last listener goes
/// away, which means popping a detail screen and re-opening it refetches
/// from scratch. A plain (non-autoDispose) provider is the other extreme: it
/// lives for the whole process, so every group/expense/friend the user ever
/// opens stays in memory — including embedded base64 receipts.
///
/// This helper is the middle ground. Call it at the top of an `autoDispose`
/// provider's build:
///
/// ```dart
/// final fooProvider = FutureProvider.autoDispose.family<Foo, String>((ref, id) {
///   keepAliveFor(ref, const Duration(minutes: 5));
///   ...
/// });
/// ```
///
/// While the provider has listeners it behaves normally. When the last
/// listener is removed, a timer starts; if nobody listens again within
/// [duration] the state is released. If a listener comes back in time, the
/// timer is cancelled and the cached value is reused instantly.
void keepAliveFor(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  Timer? timer;

  ref.onCancel(() {
    timer?.cancel();
    timer = Timer(duration, link.close);
  });
  ref.onResume(() {
    timer?.cancel();
    timer = null;
  });
  ref.onDispose(() {
    timer?.cancel();
  });
}
