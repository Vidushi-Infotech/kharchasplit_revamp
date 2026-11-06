import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Widget for displaying empty state messages
class EmptyStateWidget extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onActionPressed;
  final String? actionLabel;
  final double iconSize;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onActionPressed,
    this.actionLabel,
    this.iconSize = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Emoji
              Text(
                icon,
                style: TextStyle(fontSize: iconSize),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                title,
                style: AppTextStyles.headline2(isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                subtitle,
                style: AppTextStyles.body1(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              // Action button (if provided)
              if (onActionPressed != null && actionLabel != null) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onActionPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state for no groups
  factory EmptyStateWidget.noGroups({
    VoidCallback? onCreateGroup,
  }) {
    return EmptyStateWidget(
      icon: '👥',
      title: 'No groups yet',
      subtitle: 'Start by creating a group and inviting your friends.',
      onActionPressed: onCreateGroup,
      actionLabel: 'Create Group',
    );
  }

  /// Empty state for no expenses
  factory EmptyStateWidget.noExpenses({
    VoidCallback? onAddExpense,
  }) {
    return EmptyStateWidget(
      icon: '✨',
      title: 'Clean slate!',
      subtitle: 'Add your first expense to start tracking.',
      onActionPressed: onAddExpense,
      actionLabel: 'Add Expense',
    );
  }

  /// Empty state for no friends
  factory EmptyStateWidget.noFriends({
    VoidCallback? onAddFriend,
  }) {
    return EmptyStateWidget(
      icon: '😔',
      title: 'No friends yet',
      subtitle: 'Add friends to start splitting expenses with them.',
      onActionPressed: onAddFriend,
      actionLabel: 'Add Friend',
    );
  }

  /// Empty state for no activity
  factory EmptyStateWidget.noActivity() {
    return const EmptyStateWidget(
      icon: '📭',
      title: 'Nothing yet',
      subtitle: 'Your activity will appear here as you add expenses and settle up.',
    );
  }

  /// Empty state for all settled
  factory EmptyStateWidget.allSettled() {
    return const EmptyStateWidget(
      icon: '🎉',
      title: 'All settled up!',
      subtitle: 'You\'re all even. No debts or credits.',
    );
  }

  /// Empty state for no search results
  factory EmptyStateWidget.noSearchResults({
    String searchQuery = '',
  }) {
    return EmptyStateWidget(
      icon: '🔍',
      title: 'No results',
      subtitle: 'No expenses found matching "$searchQuery".',
    );
  }
}
