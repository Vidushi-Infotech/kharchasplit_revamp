import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/error_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
import '../widgets/contact_permission_widget.dart';
import '../widgets/friend_list_item.dart';
import '../widgets/friend_search_widget.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final friendsState = ref.watch(friendsProvider);

    // Use width-based decision (CLAUDE.md Section 5)
    if (screenWidth < 600) {
      return _buildCompactLayout(context, isDark, friendsState, ref);
    } else if (screenWidth < 1100) {
      return _buildStandardLayout(context, isDark, friendsState, ref);
    } else {
      return _buildLargeLayout(context, isDark, friendsState, ref);
    }
  }

  // Compact: <600px - Mobile layout (16-20px padding)
  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    FriendsState state,
    WidgetRef ref,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Semantics(
          label: 'Friends page',
          child: const Text('Friends'),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: _buildBody(context, isDark, state, ref, padding: 16.0),
    );
  }

  // Standard: 600-1100px - Tablet layout (24-32px padding)
  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    FriendsState state,
    WidgetRef ref,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Semantics(
          label: 'Friends page',
          child: const Text('Friends'),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: _buildBody(context, isDark, state, ref, padding: 24.0),
    );
  }

  // Large: >1100px - Desktop layout (32-48px padding)
  Widget _buildLargeLayout(
    BuildContext context,
    bool isDark,
    FriendsState state,
    WidgetRef ref,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Semantics(
          label: 'Friends page',
          child: const Text('Friends'),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: _buildBody(context, isDark, state, ref, padding: 48.0),
    );
  }

  /// Build main body content
  Widget _buildBody(
    BuildContext context,
    bool isDark,
    FriendsState state,
    WidgetRef ref, {
    required double padding,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Show permission request if not granted
    if (!state.hasPermission) {
      return ContactPermissionWidget(
        isLoading: state.isLoading,
        onRequestPermission: () {
          ref.read(friendsProvider.notifier).loadContacts();
        },
      );
    }

    // Show error state
    if (state.error != null) {
      return Column(
        children: [
          Expanded(
            child: ErrorStateWidget(
              error: state.error!,
              onRetry: () {
                ref.read(friendsProvider.notifier).refreshContacts();
              },
            ),
          ),
        ],
      );
    }

    // Main content
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 1100 ? 900 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                FriendSearchWidget(
                  isLoading: state.isLoading,
                  onSearch: (query) {
                    ref.read(friendsProvider.notifier).searchContacts(query);
                  },
                  onClear: () {
                    ref.read(friendsProvider.notifier).clearSearch();
                  },
                ),
                const SizedBox(height: 16),

                // Stats (if has friends)
                if (state.friends.isNotEmpty) ...[
                  Semantics(
                    label: 'Friends statistics',
                    child: Row(
                      children: [
                        _buildStatCard(
                          isDark,
                          label: 'Total',
                          value: state.friends.length.toString(),
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          isDark,
                          label: 'Active',
                          value: state.registeredCount.toString(),
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          isDark,
                          label: 'To Invite',
                          value: state.unregisteredCount.toString(),
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Friends list
                if (state.isLoading)
                  _buildLoadingState(isDark)
                else if (state.filteredFriends.isEmpty)
                  _buildEmptyState(isDark, state.searchQuery.isNotEmpty)
                else
                  _buildFriendsList(isDark, state, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build stat card
  Widget _buildStatCard(
    bool isDark, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.headline3(isDark).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption(isDark).copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build friends list
  Widget _buildFriendsList(
    bool isDark,
    FriendsState state,
    WidgetRef ref,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Semantics(
        label: 'Friends list',
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.filteredFriends.length,
          itemBuilder: (context, index) {
            final friend = state.filteredFriends[index];
            return FriendListItem(
              friend: friend,
              onTap: () {
                // TODO: Open friend details or chat
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening ${friend.displayName}'),
                    duration: const Duration(milliseconds: 500),
                  ),
                );
              },
              onDelete: () {
                // Show confirmation
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Friend'),
                    content: Text(
                      'Remove ${friend.displayName} from your friends?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(friendsProvider.notifier).removeFriend(
                            friend.recordId,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${friend.displayName} removed',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Build loading state with shimmer skeleton
  Widget _buildLoadingState(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.divider(isDark),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.divider(isDark),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(bool isDark, bool isSearchEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              isSearchEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
              size: 48,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              isSearchEmpty
                  ? 'No Friends Yet'
                  : 'No Results Found',
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 8),
            Text(
              isSearchEmpty
                  ? 'Your contacts will appear here'
                  : 'Try a different search',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
