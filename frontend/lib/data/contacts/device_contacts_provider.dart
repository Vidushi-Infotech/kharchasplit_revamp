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
  Future<List<Contact>> build() => _fetch();

  Future<List<Contact>> _fetch() async {
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

  /// Re-fetches while keeping the current data on screen. `invalidateSelf`
  /// re-runs [build] with refresh semantics (previous value retained,
  /// `isRefreshing == true`), so `.when()` keeps rendering the data branch
  /// instead of dropping to a skeleton. It also disposes and re-registers the
  /// listeners set up in [build], which calling `build()` by hand never did.
  /// A failed fetch lands in [state] rather than being thrown, matching the
  /// old `AsyncValue.guard` behaviour.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Already reflected in state.
    }
  }

  /// Like [refresh] but a failure is swallowed entirely — the existing list
  /// stays put and no error state is surfaced. Used to pick up contacts the
  /// user added since the picker was last opened.
  Future<void> silentRefresh() async {
    final next = await AsyncValue.guard(_fetch);
    if (next is AsyncData<List<Contact>>) {
      state = next;
    }
  }
}
