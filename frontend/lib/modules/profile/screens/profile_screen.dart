import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: screenWidth < 600
            ? _Body(user: user, isDark: isDark, maxWidth: double.infinity)
            : Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: screenWidth < 1100 ? 640 : 820),
                  child: _Body(
                    user: user,
                    isDark: isDark,
                    maxWidth: screenWidth < 1100 ? 640 : 820,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.user,
    required this.isDark,
    required this.maxWidth,
  });

  final UserModel? user;
  final bool isDark;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        _Header(isDark: isDark),
        const SizedBox(height: 20),
        _ProfileCard(user: user, isDark: isDark),
        const SizedBox(height: 24),
        _SectionLabel(label: 'ACCOUNT', isDark: isDark),
        const SizedBox(height: 8),
        _MenuGroup(
          isDark: isDark,
          items: [
            _MenuItemData(
              icon: Icons.person_outline_rounded,
              label: 'Edit profile',
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.lock_outline_rounded,
              label: 'Security',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'PREFERENCES', isDark: isDark),
        const SizedBox(height: 8),
        _MenuGroup(
          isDark: isDark,
          items: [
            _MenuItemData(
              icon: Icons.currency_rupee_rounded,
              label: 'Default currency',
              trailing: 'INR ₹',
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.language_rounded,
              label: 'Language',
              trailing: 'English',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'SUPPORT', isDark: isDark),
        const SizedBox(height: 8),
        _MenuGroup(
          isDark: isDark,
          items: [
            _MenuItemData(
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy policy',
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.description_outlined,
              label: 'Terms of service',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 28),
        _LogoutButton(
          isDark: isDark,
          onTap: () => _confirmLogout(context, ref),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'KharchaSplit · v1.0',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again to use the app."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    context.go('/login');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROFILE',
          style: AppTextStyles.caption(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your account',
          style: AppTextStyles.headline1(isDark).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.isDark});

  final UserModel? user;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Guest';
    final phone = user?.phone ?? '';
    final email = user?.email ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AvatarWidget(
            imageUrl: user?.avatarUrl,
            name: name,
            radius: 30,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headline3(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items, required this.isDark});

  final List<_MenuItemData> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _MenuRow(item: items[i], isDark: isDark),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.isDark});
  final _MenuItemData item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppColors.divider(isDark).withValues(alpha: 0.6),
                  ),
                ),
                child: Icon(
                  item.icon,
                  size: 17,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.trailing != null) ...[
                Text(
                  item.trailing!,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isDark, required this.onTap});
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log out',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Log out',
                  style: AppTextStyles.body1(isDark).copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
