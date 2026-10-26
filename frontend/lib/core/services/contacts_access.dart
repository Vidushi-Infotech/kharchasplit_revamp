import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// How much of the address book the app may read.
enum ContactsAccess {
  full,

  /// iOS 18+: only the contacts the person chose ("Select Contacts").
  limited,
  denied,
  notDetermined,

  /// Not reported on this platform (Android, web): treat as before.
  unknown,
}

/// iOS contacts permission details flutter_contacts doesn't expose
/// (native side: ContactsAccessPlugin in ios/Runner/AppDelegate.swift).
abstract final class ContactsAccessService {
  static const _channel = MethodChannel('kharchasplit/contacts_access');

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  static Future<ContactsAccess> status() async {
    if (!_isIOS) return ContactsAccess.unknown;
    try {
      final s = await _channel.invokeMethod<String>('status');
      return switch (s) {
        'full' => ContactsAccess.full,
        'limited' => ContactsAccess.limited,
        'denied' || 'restricted' => ContactsAccess.denied,
        'notDetermined' => ContactsAccess.notDetermined,
        _ => ContactsAccess.unknown,
      };
    } catch (_) {
      return ContactsAccess.unknown;
    }
  }

  /// Apple's picker for sharing more contacts with the app (iOS 18+, when
  /// access is limited). Returns how many were added.
  static Future<int> addMoreContacts() async {
    if (!_isIOS) return 0;
    try {
      return await _channel.invokeMethod<int>('addMoreContacts') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// One contact from the system picker, which needs no contacts
  /// permission (so it works with limited or no access). Null when
  /// cancelled or off iOS.
  static Future<Contact?> pickContact() async {
    if (!_isIOS) return null;
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('pickContact');
      if (m == null) return null;
      final phones = (m['phones'] as List?)?.whereType<String>() ?? const [];
      return Contact(
        id: (m['id'] as String?) ?? '',
        displayName: (m['name'] as String?) ?? '',
        phones: [for (final p in phones) Phone(p)],
      );
    } catch (_) {
      return null;
    }
  }

  /// The app's page in Settings, where contacts access can be changed.
  static Future<void> openSettings() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }
}
