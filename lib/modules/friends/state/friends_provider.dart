import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/contacts_service.dart';
import '../../../core/services/contacts_cache_service.dart';
import '../../../models/contact_model.dart';

/// Friends/Contacts list state
class FriendsState {
  final List<ExtendedContactModel> friends;
  final bool isLoading;
  final bool hasPermission;
  final String? error;
  final String searchQuery;

  const FriendsState({
    required this.friends,
    required this.isLoading,
    required this.hasPermission,
    this.error,
    required this.searchQuery,
  });

  FriendsState copyWith({
    List<ExtendedContactModel>? friends,
    bool? isLoading,
    bool? hasPermission,
    String? error,
    String? searchQuery,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get filtered friends by search query
  List<ExtendedContactModel> get filteredFriends {
    if (searchQuery.isEmpty) return friends;

    final lowerQuery = searchQuery.toLowerCase();
    return friends
        .where((friend) =>
            friend.displayName.toLowerCase().contains(lowerQuery) ||
            (friend.primaryPhone?.contains(lowerQuery) ?? false))
        .toList();
  }

  /// Get registered friends count
  int get registeredCount => friends.where((f) => f.isRegistered).length;

  /// Get unregistered friends count
  int get unregisteredCount => friends.where((f) => !f.isRegistered).length;
}

/// Friends notifier for managing state
class FriendsNotifier extends Notifier<FriendsState> {
  @override
  FriendsState build() {
    _initalize();
    return const FriendsState(
      friends: [],
      isLoading: true,
      hasPermission: false,
      error: null,
      searchQuery: '',
    );
  }

  /// Initialize contacts and cache
  Future<void> _initalize() async {
    try {
      // Initialize cache
      await contactsCacheService.init();
      print('[FriendsProvider] Cache initialized');

      // Load contacts
      await loadContacts();
    } catch (e) {
      print('[FriendsProvider] Init error: $e');
    }
  }

  /// Load contacts from device
  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Request permission if needed
      final hasPermission = await contactsService.requestContactPermission();
      state = state.copyWith(hasPermission: hasPermission);

      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          error: 'Contact permission denied',
        );
        return;
      }

      // Get valid contacts
      final contacts = await contactsService.getValidContacts();
      print('[FriendsProvider] Loaded ${contacts.length} contacts');

      // Convert to extended contacts with mock registration status
      final extendedContacts = contacts.map((contact) {
        // TODO: Check registration status from backend
        // For now, mark some as registered based on index
        final isRegistered = contact.recordId.hashCode.isEven;

        return ExtendedContactModel.from(
          contact,
          isRegistered: isRegistered,
          userProfile: isRegistered
              ? {
                  'name': contact.displayName,
                  'phone': contact.primaryPhone,
                }
              : null,
        );
      }).toList();

      // Cache contacts
      for (final contact in extendedContacts) {
        if (contact.primaryPhone != null) {
          await contactsCacheService.set(
            contact.primaryPhone!,
            isRegistered: contact.isRegistered,
            userProfile: contact.userProfile,
          );
        }
      }

      state = state.copyWith(
        friends: extendedContacts,
        isLoading: false,
      );
    } catch (e) {
      print('[FriendsProvider] Load contacts error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load contacts: ${e.toString()}',
      );
    }
  }

  /// Search contacts
  void searchContacts(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Refresh contacts
  Future<void> refreshContacts() async {
    await loadContacts();
  }

  /// Add friend (mock)
  Future<void> addFriend(ExtendedContactModel contact) async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: Save to backend
      print('[FriendsProvider] Adding friend: ${contact.displayName}');

      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      final updated = state.copyWith(
        friends: [...state.friends, contact],
        isLoading: false,
      );
      state = updated;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to add friend: ${e.toString()}',
      );
    }
  }

  /// Remove friend (mock)
  Future<void> removeFriend(String recordId) async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: Remove from backend
      print('[FriendsProvider] Removing friend: $recordId');

      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      final updated = state.copyWith(
        friends: state.friends.where((f) => f.recordId != recordId).toList(),
        isLoading: false,
      );
      state = updated;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to remove friend: ${e.toString()}',
      );
    }
  }
}

/// Riverpod provider for friends state
final friendsProvider =
    NotifierProvider<FriendsNotifier, FriendsState>(FriendsNotifier.new);
