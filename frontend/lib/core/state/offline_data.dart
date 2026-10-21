import 'package:flutter/foundation.dart';

/// What the app is showing from the offline cache right now.
///
/// The cache interceptor reports each response it served from the cache
/// ([servedFromCache]) and each fresh one ([fresh]); [staleSince] is the
/// oldest "saved at" time still on screen, which the offline banner turns
/// into "showing data from 2h ago". Plain singleton because the
/// interceptor lives below the widget tree.
class OfflineData {
  OfflineData._();
  static final instance = OfflineData._();

  final _servedAt = <String, DateTime>{};

  /// Oldest cached data currently in use; null when everything is fresh.
  final staleSince = ValueNotifier<DateTime?>(null);

  void servedFromCache(String key, DateTime savedAt) {
    _servedAt[key] = savedAt;
    _publish();
  }

  void fresh(String key) {
    if (_servedAt.remove(key) != null) _publish();
  }

  /// Signed out / account switched: nothing cached is on screen any more.
  void reset() {
    _servedAt.clear();
    _publish();
  }

  void _publish() {
    staleSince.value = _servedAt.isEmpty
        ? null
        : _servedAt.values.reduce((a, b) => a.isBefore(b) ? a : b);
  }
}

/// "just now", "5 min ago", "2h ago", "yesterday", "3 days ago".
String formatAgo(DateTime then, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays} days ago';
}
