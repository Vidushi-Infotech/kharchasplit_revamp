import 'package:hive_flutter/hive_flutter.dart';

import '../services/app_logger.dart';
import '../state/offline_data.dart';

/// On-device storage for offline use (Hive; IndexedDB on web).
///
/// * [httpCacheBox] — last good responses of read-only GETs, shown with a
///   "last updated" time while offline.
/// * [outboxBox] — changes made offline (or whose request failed for lack
///   of a connection), sent in order when the connection is back.
///
/// Values are JSON strings keyed by cache key / outbox item id. Both boxes
/// belong to the signed-in user and are wiped on sign-out
/// ([clearUserData]). If Hive can't open (rare: corrupt storage, private
/// mode on web) the app keeps working online-only — [box] returns null.
class LocalStore {
  static const httpCacheBox = 'http_cache';
  static const outboxBox = 'outbox';

  static bool _ready = false;

  /// Call once before runApp.
  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox<String>(httpCacheBox),
        Hive.openBox<String>(outboxBox),
      ]);
      _ready = true;
    } catch (e, st) {
      AppLogger.error('Local store unavailable — offline mode off',
          tag: 'LocalStore', error: e, stackTrace: st);
    }
  }

  static Box<String>? box(String name) =>
      _ready && Hive.isBoxOpen(name) ? Hive.box<String>(name) : null;

  /// Signing out (or deleting the account): nothing of this user may stay
  /// on the device — cached data or unsent changes.
  static Future<void> clearUserData() async {
    try {
      await box(httpCacheBox)?.clear();
      await box(outboxBox)?.clear();
      OfflineData.instance.reset();
    } catch (e) {
      AppLogger.error('Could not clear local store', tag: 'LocalStore', error: e);
    }
  }
}
