import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/profile_avatar_widget.dart';
import '../widgets/profile_info_widget.dart';
import '../widgets/profile_stats_widget.dart';
import '../widgets/profile_actions_widget.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Semantics(
          label: 'Profile page',
          child: const Text('Profile'),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: screenWidth < 600
            ? _buildCompactLayout(context, isDark, ref)
            : screenWidth < 1100
                ? _buildStandardLayout(context, isDark, ref)
                : _buildLargeLayout(context, isDark, ref),
      ),
    );
  }

  // Compact: <600px - Mobile layout (16-20px padding)
  Widget _buildCompactLayout(BuildContext context, bool isDark, WidgetRef ref) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            ProfileAvatarWidget(
              name: 'You',
              onUpload: () {},
              onRegenerate: () {},
            ),
            const SizedBox(height: 20),
            ProfileInfoWidget(
              name: 'John Doe',
              email: 'john@example.com',
              phone: '+91 98765 43210',
              onEditName: () {},
              onEditEmail: () {},
              onEditPhone: () {},
            ),
            const SizedBox(height: 20),
            ProfileStatsWidget(
              totalExpenses: 24,
              totalGroups: 5,
              totalSpent: 15850.00,
            ),
            const SizedBox(height: 20),
            ProfileActionsWidget(
              onHelp: () {},
              onPrivacy: () {},
              onLogout: () {},
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Standard: 600-1100px - Tablet layout (24-32px padding)
  Widget _buildStandardLayout(BuildContext context, bool isDark, WidgetRef ref) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                ProfileAvatarWidget(
                  name: 'You',
                  onUpload: () {},
                  onRegenerate: () {},
                ),
                const SizedBox(height: 28),
                ProfileInfoWidget(
                  name: 'John Doe',
                  email: 'john@example.com',
                  phone: '+91 98765 43210',
                  onEditName: () {},
                  onEditEmail: () {},
                  onEditPhone: () {},
                ),
                const SizedBox(height: 24),
                ProfileStatsWidget(
                  totalExpenses: 24,
                  totalGroups: 5,
                  totalSpent: 15850.00,
                ),
                const SizedBox(height: 24),
                ProfileActionsWidget(
                  onHelp: () {},
                  onPrivacy: () {},
                  onLogout: () {},
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Large: >1100px - Desktop layout (32-48px padding)
  Widget _buildLargeLayout(BuildContext context, bool isDark, WidgetRef ref) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Avatar + Info
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      ProfileAvatarWidget(
                        name: 'You',
                        onUpload: () {},
                        onRegenerate: () {},
                      ),
                      const SizedBox(height: 32),
                      ProfileInfoWidget(
                        name: 'John Doe',
                        email: 'john@example.com',
                        phone: '+91 98765 43210',
                        onEditName: () {},
                        onEditEmail: () {},
                        onEditPhone: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                // Right: Stats + Actions
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      ProfileStatsWidget(
                        totalExpenses: 24,
                        totalGroups: 5,
                        totalSpent: 15850.00,
                      ),
                      const SizedBox(height: 32),
                      ProfileActionsWidget(
                        onHelp: () {},
                        onPrivacy: () {},
                        onLogout: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
