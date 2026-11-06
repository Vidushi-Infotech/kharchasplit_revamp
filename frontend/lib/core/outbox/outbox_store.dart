import 'dart:async';
import 'dart:convert';

import '../storage/local_store.dart';
import 'outbox_item.dart';

/// The outbox on disk (Hive, one JSON string per item, keyed by id), so
/// queued changes survive the app being killed. Broadcasts [changes] on
/// every write and [queued] when a write was put in the outbox instead of
/// being sent (the offline banner shows "Saved offline").
abstract final class OutboxStore {
  static final _changes = StreamController<void>.broadcast();
  static final _queued = StreamController<OutboxItem>.broadcast();

  static Stream<void> get changes => _changes.stream;
  static Stream<OutboxItem> get queued => _queued.stream;

  /// False when Hive isn't available — then nothing is queued.
  static bool get available => LocalStore.box(LocalStore.outboxBox) != null;

  /// [userId]'s items, oldest first.
  static List<OutboxItem> itemsFor(String? userId) {
    final box = LocalStore.box(LocalStore.outboxBox);
    if (box == null || userId == null) return const [];
    final items = <OutboxItem>[];
    for (final raw in box.values) {
      try {
        final item = OutboxItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (item.userId == userId) items.add(item);
      } catch (_) {/* unreadable entry — skipped */}
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  /// Replace [userId]'s queue with [items] (after a merge).
  static Future<void> saveAll(String userId, List<OutboxItem> items) async {
    final box = LocalStore.box(LocalStore.outboxBox);
    if (box == null) return;
    final keep = {for (final i in items) i.id};
    final stale = itemsFor(userId).where((i) => !keep.contains(i.id)).map((i) => i.id);
    await box.deleteAll(stale);
    await box.putAll({for (final i in items) i.id: jsonEncode(i.toJson())});
    _changes.add(null);
  }

  static Future<void> put(OutboxItem item) async {
    await LocalStore.box(LocalStore.outboxBox)?.put(item.id, jsonEncode(item.toJson()));
    _changes.add(null);
  }

  static Future<void> remove(String id) async {
    await LocalStore.box(LocalStore.outboxBox)?.delete(id);
    _changes.add(null);
  }

  static void announceQueued(OutboxItem item) => _queued.add(item);
}
