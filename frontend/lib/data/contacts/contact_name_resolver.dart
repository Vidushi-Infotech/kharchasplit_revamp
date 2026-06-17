import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_contacts_provider.dart';

/// Last-10-digits of a phone number, used as a match key so that numbers
/// stored in different formats (+91 98765 43210, 098765 43210, 9876543210)
/// all collapse to the same key.
String normalizePhoneKey(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

/// True when a string is essentially just a phone number (digits plus the
/// usual separators). Used to detect backend "name" values that are really a
/// phone-number fallback for a user who never set a display name.
bool looksLikePhone(String s) {
  final t = s.trim();
  if (t.isEmpty) return false;
  if (!RegExp(r'^[0-9 +\-()]+$').hasMatch(t)) return false;
  return t.replaceAll(RegExp(r'[^0-9]'), '').length >= 7;
}

/// normalized-phone → device contact display name. Empty while contacts are
/// still loading or when contacts permission was denied (the resolver simply
/// returns no match in that case, so callers fall back to other sources).
final contactNameByPhoneProvider = Provider<Map<String, String>>((ref) {
  final contacts = ref.watch(deviceContactsProvider).value ?? const [];
  final map = <String, String>{};
  for (final c in contacts) {
    final name = c.displayName.trim();
    if (name.isEmpty) continue;
    for (final phone in c.phones) {
      final key = normalizePhoneKey(phone.number);
      if (key.length >= 7) map.putIfAbsent(key, () => name);
    }
  }
  return map;
});

/// Resolves the best display name for a person, preferring (in order):
/// 1. their real registered name (non-empty, not just a phone number),
/// 2. the name saved for their phone in the device address book,
/// 3. the registered/phone-fallback string as-is,
/// 4. their phone number,
/// 5. a safe placeholder.
String resolveDisplayName({
  required String backendName,
  required String phone,
  required Map<String, String> contactNameByPhone,
  String placeholder = 'Unknown member',
}) {
  final name = backendName.trim();
  final hasRealName = name.isNotEmpty && !looksLikePhone(name);
  if (hasRealName) return name;

  if (phone.isNotEmpty) {
    final contact = contactNameByPhone[normalizePhoneKey(phone)];
    if (contact != null && contact.isNotEmpty) return contact;
  }

  if (name.isNotEmpty) return name; // phone-as-name fallback from backend
  if (phone.isNotEmpty) return phone;
  return placeholder;
}
