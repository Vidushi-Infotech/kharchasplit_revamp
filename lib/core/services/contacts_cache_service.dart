import 'package:hive/hive.dart';
import '../../models/contact_model.dart';
import '../utils/phone_formatter.dart';

/// Cached contact with timestamp
class CachedContact {
  final String phoneNumber;
  final bool isRegistered;
  final Map<String, dynamic>? userProfile;
  final DateTime timestamp;

  CachedContact({
    required this.phoneNumber,
    required this.isRegistered,
    this.userProfile,
    required this.timestamp,
  });

  /// Check if cache entry is expired (10 minutes TTL)
  bool get isExpired {
    final now = DateTime.now();
    final duration = now.difference(timestamp);
    return duration.inMinutes > 10;
  }
}

/// Service for caching contact registration status
class ContactsCacheService {
  static const String _cacheBoxName = 'contacts_cache';
  static const int _maxCacheSize = 1000;
  static const int _cacheDurationMinutes = 10;

  late Box<Map> _cacheBox;
  bool _initialized = false;

  /// Initialize the cache service
  Future<void> init() async {
    if (_initialized) return;

    try {
      _cacheBox = await Hive.openBox<Map>(_cacheBoxName);
      _cleanExpiredEntries();
      _initialized = true;
      print('[ContactsCache] Initialized successfully');
    } catch (e) {
      print('[ContactsCache] Init error: $e');
      rethrow;
    }
  }

  /// Get cached contact info
  CachedContact? get(String phoneNumber) {
    if (!_initialized) return null;

    final normalized = PhoneFormatter.normalizePhone(phoneNumber);
    final cached = _cacheBox.get(normalized);

    if (cached == null) return null;

    try {
      final contact = CachedContact(
        phoneNumber: normalized,
        isRegistered: cached['isRegistered'] ?? false,
        userProfile: Map<String, dynamic>.from(cached['userProfile'] ?? {}),
        timestamp: DateTime.parse(cached['timestamp'] ?? DateTime.now().toIso8601String()),
      );

      // Return null if expired
      if (contact.isExpired) {
        delete(normalized);
        return null;
      }

      return contact;
    } catch (e) {
      print('[ContactsCache] Get error: $e');
      return null;
    }
  }

  /// Set cached contact info
  Future<void> set(
    String phoneNumber, {
    required bool isRegistered,
    Map<String, dynamic>? userProfile,
  }) async {
    if (!_initialized) return;

    try {
      final normalized = PhoneFormatter.normalizePhone(phoneNumber);

      // Check size limit
      if (_cacheBox.length >= _maxCacheSize) {
        await _cleanExpiredEntries();
        // If still over limit, remove 10% oldest entries
        if (_cacheBox.length >= _maxCacheSize) {
          final toRemove = (_maxCacheSize * 0.1).toInt();
          await _cacheBox.deleteAt(0); // Remove oldest
        }
      }

      await _cacheBox.put(normalized, {
        'isRegistered': isRegistered,
        'userProfile': userProfile ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      });

      print('[ContactsCache] Cached $normalized - isRegistered: $isRegistered');
    } catch (e) {
      print('[ContactsCache] Set error: $e');
    }
  }

  /// Get multiple cached contacts
  List<CachedContact> getMultiple(List<String> phoneNumbers) {
    return phoneNumbers
        .map((phone) => get(phone))
        .whereType<CachedContact>()
        .toList();
  }

  /// Delete a cached contact
  Future<void> delete(String phoneNumber) async {
    if (!_initialized) return;

    try {
      final normalized = PhoneFormatter.normalizePhone(phoneNumber);
      await _cacheBox.delete(normalized);
    } catch (e) {
      print('[ContactsCache] Delete error: $e');
    }
  }

  /// Clean expired entries
  Future<void> _cleanExpiredEntries() async {
    if (!_initialized) return;

    try {
      final keysToDelete = <String>[];

      for (final key in _cacheBox.keys) {
        final cached = _cacheBox.get(key);
        if (cached != null) {
          try {
            final timestamp = DateTime.parse(
              cached['timestamp'] ?? DateTime.now().toIso8601String(),
            );
            final now = DateTime.now();
            if (now.difference(timestamp).inMinutes > _cacheDurationMinutes) {
              keysToDelete.add(key as String);
            }
          } catch (e) {
            keysToDelete.add(key as String);
          }
        }
      }

      for (final key in keysToDelete) {
        await _cacheBox.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        print('[ContactsCache] Cleaned ${keysToDelete.length} expired entries');
      }
    } catch (e) {
      print('[ContactsCache] Clean expired error: $e');
    }
  }

  /// Clear all cache
  Future<void> clear() async {
    if (!_initialized) return;

    try {
      await _cacheBox.clear();
      print('[ContactsCache] Cache cleared');
    } catch (e) {
      print('[ContactsCache] Clear error: $e');
    }
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    if (!_initialized) {
      return {'total': 0, 'registered': 0, 'unregistered': 0};
    }

    int registered = 0;
    int unregistered = 0;

    for (final cached in _cacheBox.values) {
      if (cached['isRegistered'] == true) {
        registered++;
      } else {
        unregistered++;
      }
    }

    return {
      'total': _cacheBox.length,
      'registered': registered,
      'unregistered': unregistered,
    };
  }

  /// Close the cache (call on app shutdown)
  Future<void> close() async {
    if (_initialized) {
      await _cacheBox.close();
      _initialized = false;
    }
  }
}

/// Singleton instance
final contactsCacheService = ContactsCacheService();
