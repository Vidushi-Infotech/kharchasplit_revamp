import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: screenWidth < 600
          ? _buildCompactLayout(isDark)
          : screenWidth < 1100
              ? _buildStandardLayout(isDark)
              : _buildLargeLayout(isDark),
    );
  }

  /// Compact layout for mobile (< 600px)
  Widget _buildCompactLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildProfileHeader(isDark),
          const SizedBox(height: 40),
          _buildProfileMenu(isDark),
        ],
      ),
    );
  }

  /// Standard layout for tablets (600-1100px)
  Widget _buildStandardLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildProfileHeader(isDark),
              const SizedBox(height: 48),
              _buildProfileMenu(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Large layout for desktop (> 1100px)
  Widget _buildLargeLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildProfileHeader(isDark),
              const SizedBox(height: 56),
              _buildProfileMenu(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Profile header with avatar and name
  Widget _buildProfileHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.tealDark.withOpacity(0.2),
          ),
          child: const Icon(Icons.person_rounded, size: 40),
        ),
        const SizedBox(height: 16),
        Text('You', style: AppTextStyles.headline2(isDark)),
        const SizedBox(height: 8),
        Text(
          'user@example.com',
          style: AppTextStyles.body2(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }

  /// Profile menu items
  Widget _buildProfileMenu(bool isDark) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Settings menu item - configure app preferences',
          child: ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings'),
            onTap: () {},
          ),
        ),
        Semantics(
          button: true,
          label: 'Help and support menu item - view help documentation',
          child: ListTile(
            leading: const Icon(Icons.help_rounded),
            title: const Text('Help & Support'),
            onTap: () {},
          ),
        ),
        Semantics(
          button: true,
          label: 'Privacy policy menu item - read privacy terms',
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: const Text('Privacy Policy'),
            onTap: () {},
          ),
        ),
        Semantics(
          button: true,
          label: 'Logout menu item - sign out and return to login',
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Logout'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
