import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/services/haptic_service.dart';
import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/dialogs/donate_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';

/// Default-currency preference row on the profile screen. See the
/// comment at the use site for why it is off.
const bool _kShowDefaultCurrency = false;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: screenWidth < 600
            ? _Body(user: user, isDark: isDark, maxWidth: double.infinity)
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth < 1100 ? 640 : 820,
                  ),
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
    return RefreshIndicator(
      onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        physics: const AlwaysScrollableScrollPhysics(),
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
                onTap: () => context.pushNamed('edit-profile'),
              ),
              _MenuItemData(
                icon: Icons.timeline_rounded,
                label: 'Activity',
                onTap: () => context.pushNamed('activity'),
              ),
              _MenuItemData(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () => context.pushNamed('notification-settings'),
              ),
              _MenuItemData(
                icon: Icons.lock_outline_rounded,
                label: 'Security',
                onTap: () => context.pushNamed('security'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: 'APPEARANCE', isDark: isDark),
          const SizedBox(height: 8),
          _ThemePicker(isDark: isDark),
          const SizedBox(height: 20),
          // Hidden until the preference is actually honoured by the create-
          // group / add-expense flows; today it saves to the backend but
          // nothing reads it, so showing it would mislead. Flip the flag to
          // bring the section back — the picker and update path still work.
          if (_kShowDefaultCurrency) ...[
          _SectionLabel(label: 'PREFERENCES', isDark: isDark),
          const SizedBox(height: 8),
          _MenuGroup(
            isDark: isDark,
            items: [
              _MenuItemData(
                icon: Icons.currency_exchange_rounded,
                label: 'Default currency',
                trailing: _CurrencyPicker.labelFor(
                  user?.preferredCurrency ?? 'INR',
                ),
                onTap: () => _CurrencyPicker.show(
                  context,
                  current: user?.preferredCurrency ?? 'INR',
                  onSelected: (code) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref
                        .read(authProvider.notifier)
                        .updateProfile(preferredCurrency: code);
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Default currency updated to ${_CurrencyPicker.labelFor(code)}'
                              : 'Could not update currency',
                        ),
                        backgroundColor: ok ? null : AppColors.warning,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ],
          _SectionLabel(label: 'SUPPORT', isDark: isDark),
          const SizedBox(height: 8),
          _MenuGroup(
            isDark: isDark,
            items: [
              _MenuItemData(
                icon: Icons.favorite_rounded,
                label: 'Support us / Donate',
                onTap: () => showDonateSheet(context),
              ),
              _MenuItemData(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () => _HelpSupportSheet.show(context),
              ),
              _MenuItemData(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy policy',
                onTap: () => context.pushNamed('privacy-policy'),
              ),
              _MenuItemData(
                icon: Icons.description_outlined,
                label: 'Terms of service',
                onTap: () => context.pushNamed('terms'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _LogoutButton(
            isDark: isDark,
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 16),
          Center(child: _VersionFooter(isDark: isDark)),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogoutSheet(),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Signing out…'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
    HapticService.instance.destructive();
    try {
      await ref.read(authProvider.notifier).logout();
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Signed out'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/login');
    } catch (e) {
      // logout() is best-effort and clears local state regardless,
      // but surface anything unexpected so the user knows what happened.
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sign out hit a snag: $e'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/login');
    }
  }
}

/// Confirmation bottom sheet for logout — replaces the old AlertDialog so
/// it matches the rest of the app's destructive flows (Delete account,
/// Sign out everywhere).
class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.divider(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 28,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Log out?',
              textAlign: TextAlign.center,
              style: AppTextStyles.headline3(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              "You'll need to sign in again on this device to use the app.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark), height: 1.45),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(isDark),
                      side: BorderSide(color: AppColors.divider(isDark)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Log out'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
          ),
        ),
        const DonateHeartButton(size: 44, iconSize: 20, cornerRadius: 14),
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
          AvatarWidget(imageUrl: user?.avatarUrl, name: name, radius: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headline3(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: AppTextStyles.body2(
                      isDark,
                    ).copyWith(color: AppColors.textSecondary(isDark)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppTextStyles.caption(
                      isDark,
                    ).copyWith(color: AppColors.textSecondary(isDark)),
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
                  style: AppTextStyles.body1(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
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

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          _ThemeOption(
            icon: Icons.brightness_auto_rounded,
            label: 'System',
            selected: mode == AppThemeMode.system,
            isDark: isDark,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(AppThemeMode.system),
          ),
          _ThemeOption(
            icon: Icons.light_mode_rounded,
            label: 'Light',
            selected: mode == AppThemeMode.light,
            isDark: isDark,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(AppThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            selected: mode == AppThemeMode.dark,
            isDark: isDark,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(AppThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary(isDark);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: fg,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                Icon(Icons.logout_rounded, size: 18, color: AppColors.warning),
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

class _CurrencyOption {
  const _CurrencyOption(this.code, this.symbol, this.name);
  final String code;
  final String symbol;
  final String name;
}

class _CurrencyPicker {
  _CurrencyPicker._();

  /// Currencies KharchaSplit ships with. Easy to extend later.
  static const List<_CurrencyOption> options = [
    _CurrencyOption('INR', '₹', 'Indian Rupee'),
    _CurrencyOption('USD', '\$', 'US Dollar'),
    _CurrencyOption('EUR', '€', 'Euro'),
    _CurrencyOption('GBP', '£', 'British Pound'),
    _CurrencyOption('AED', 'د.إ', 'UAE Dirham'),
    _CurrencyOption('SGD', 'S\$', 'Singapore Dollar'),
    _CurrencyOption('AUD', 'A\$', 'Australian Dollar'),
    _CurrencyOption('CAD', 'C\$', 'Canadian Dollar'),
    _CurrencyOption('JPY', '¥', 'Japanese Yen'),
  ];

  static String labelFor(String code) {
    final opt = options.firstWhere(
      (o) => o.code == code,
      orElse: () => _CurrencyOption(code, '', code),
    );
    return opt.symbol.isEmpty ? opt.code : '${opt.code} ${opt.symbol}';
  }

  static void show(
    BuildContext context, {
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _CurrencyPickerSheet(
        current: current,
        onSelected: (code) {
          Navigator.of(sheetContext).pop();
          onSelected(code);
        },
      ),
    );
  }
}

class _CurrencyPickerSheet extends StatelessWidget {
  const _CurrencyPickerSheet({required this.current, required this.onSelected});

  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Default currency',
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(isDark),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.divider(isDark),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Used as the default for new groups and personal expenses.',
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: _CurrencyPicker.options.length,
                  itemBuilder: (context, index) {
                    final opt = _CurrencyPicker.options[index];
                    final selected = opt.code == current;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CurrencyRow(
                        option: opt,
                        isSelected: selected,
                        isDark: isDark,
                        onTap: () => onSelected(opt.code),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final _CurrencyOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.tealDark.withValues(alpha: 0.10)
                : AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.tealDark.withValues(alpha: 0.40)
                  : AppColors.divider(isDark),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.tealDark.withValues(alpha: 0.18)
                      : AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.divider(isDark).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  option.symbol.isEmpty ? option.code[0] : option.symbol,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isSelected
                        ? AppColors.tealDark
                        : AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.code,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.name,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.tealDark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpSupportSheet extends StatelessWidget {
  const _HelpSupportSheet();

  static const String supportEmail = 'support@kharchasplit.com';

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _HelpSupportSheet(),
    );
  }

  Future<void> _emailUs(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'KharchaSplit support'},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app available. Copied the address instead.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Clipboard.setData(const ClipboardData(text: supportEmail));
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support email copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.divider(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  size: 28,
                  color: AppColors.tealDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Need help?',
              textAlign: TextAlign.center,
              style: AppTextStyles.headline3(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              "Reach out and we'll get back as soon as we can.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark), height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider(isDark)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: AppColors.divider(isDark).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'EMAIL US',
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          supportEmail,
                          style: AppTextStyles.body1(isDark).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(isDark),
                      side: BorderSide(color: AppColors.divider(isDark)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GradientButton(
                    label: 'Send email',
                    icon: Icons.send_rounded,
                    onTap: () => _emailUs(context),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.tealLight, AppColors.tealDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDark.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body1(isDark).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reads the running app's marketing version + build number from
/// `package_info_plus` so the footer always reflects whatever was bundled
/// into the APK / IPA — no hardcoded string to drift each release.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final label = snap.hasData
            ? 'KharchaSplit · v${snap.data!.version} (${snap.data!.buildNumber})'
            : 'KharchaSplit';
        return Text(
          label,
          style: AppTextStyles.caption(
            isDark,
          ).copyWith(color: AppColors.textSecondary(isDark)),
        );
      },
    );
  }
}
