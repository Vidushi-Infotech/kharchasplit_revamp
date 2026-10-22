import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';

/// Flat settings row on the Account tab: icon, label, optional value on
/// the right, chevron, hairline divider. No card around it.
class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.valueColor,
    this.color,
    this.showChevron = true,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Right-aligned current value, e.g. "Dark" or a UPI ID.
  final String? value;
  final Color? valueColor;

  /// Icon and label color (Log out uses the warning tone).
  final Color? color;
  final bool showChevron;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = color ?? AppColors.textPrimary(isDark);
    final secondary = AppColors.textSecondary(isDark);
    return Semantics(
      button: true,
      label: value == null ? label : '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: AppColors.divider(isDark),
                        width: 0.6,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color ?? secondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1(isDark).copyWith(
                      color: fg,
                      fontWeight: color == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.body2(
                        isDark,
                      ).copyWith(color: valueColor ?? secondary),
                    ),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 20, color: secondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Appearance" row: shows the current theme; a tap opens a small sheet
/// to pick System default / Light / Dark.
class AccountThemeRow extends ConsumerWidget {
  const AccountThemeRow({super.key, this.showDivider = true});

  final bool showDivider;

  static const _options = <(AppThemeMode, String, IconData)>[
    (
      AppThemeMode.system,
      AppStrings.themeSystem,
      Icons.brightness_auto_rounded,
    ),
    (AppThemeMode.light, AppStrings.themeLight, Icons.light_mode_rounded),
    (AppThemeMode.dark, AppStrings.themeDark, Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final current = _options.firstWhere((o) => o.$1 == mode);
    return AccountRow(
      icon: Icons.palette_outlined,
      label: AppStrings.appearance,
      value: current.$2,
      showDivider: showDivider,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        // Above the shell's tab bar and floating button.
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label, icon) in _options)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  trailing: value == mode
                      ? const Icon(Icons.check_rounded, color: AppColors.brand)
                      : null,
                  selected: value == mode,
                  selectedColor: AppColors.brand,
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
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
class AccountVersionFooter extends StatelessWidget {
  const AccountVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
