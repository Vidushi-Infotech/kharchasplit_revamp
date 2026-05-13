import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContactsPermissionDenied implements Exception {
  const ContactsPermissionDenied();
  @override
  String toString() => 'Contacts permission denied';
}

/// Session-cached device contacts. Build runs once when the provider is first
/// read; subsequent reads return the cached list instantly. Call `refresh()`
/// to force a re-fetch (e.g. from a pull-to-refresh).
///
/// Pre-warm by calling `ref.read(deviceContactsProvider.future)` from any
/// screen that's likely to open the contacts picker — by the time the user
/// taps "Add from contacts", the list is already in memory.
final deviceContactsProvider =
    AsyncNotifierProvider<DeviceContactsNotifier, List<Contact>>(
  DeviceContactsNotifier.new,
);

class DeviceContactsNotifier extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() async {
    final ok = await FlutterContacts.requestPermission(readonly: true);
    if (!ok) throw const ContactsPermissionDenied();

    // withProperties=true → load phones + emails (we need phones for matching).
    // withThumbnail=false → skip avatar bytes; saves a lot of memory + time.
    return FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: false,
      sorted: true,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Re-fetch without flipping state to AsyncLoading — the existing list stays
  /// visible while the new one is fetched, then swaps in atomically. Used to
  /// pick up contacts the user added since the picker was last opened.
  Future<void> silentRefresh() async {
    final next = await AsyncValue.guard(build);
    if (next is AsyncData<List<Contact>>) {
      state = next;
    }
    // On error, keep the existing data — failure is silent.
  }
}
