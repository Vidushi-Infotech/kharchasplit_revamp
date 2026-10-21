import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// One-time "A new look" sheet introducing the Splitwise-style tab bar
/// (Groups · Friends · ➕ · Activity · Account).
///
/// Called from the mobile and tablet shells after their first frame. The
/// web sidebar already lists every destination by name, so the desktop
/// shell skips it. Any SharedPreferences failure skips the sheet silently —
/// a missed tip is better than a crash or a sheet on every launch.
class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet._();

  static const String _prefsKey = 'whats_new_tabs_v1';

  /// Guards against re-checking prefs on every shell rebuild.
  static bool _checkedThisSession = false;

  /// Shows the sheet once per install. Safe to call on every build.
  static void maybeShow(BuildContext context) {
    if (_checkedThisSession) return;
    _checkedThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(_prefsKey) ?? false) return;
        await prefs.setBool(_prefsKey, true);
      } catch (_) {
        return;
      }
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const WhatsNewSheet._(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        // Tablets get a centred card instead of a full-width slab.
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.fromLTRB(22, 14, 22, 18 + bottomInset * 0.5),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  AppStrings.whatsNewTitle,
                  style: AppTextStyles.headline2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
                ),
              ),
              const SizedBox(height: 16),
              _Bullet(
                icon: Icons.groups_rounded,
                text: AppStrings.whatsNewGroups,
                isDark: isDark,
              ),
              _Bullet(
                icon: Icons.person_rounded,
                text: AppStrings.whatsNewFriends,
                isDark: isDark,
              ),
              _Bullet(
                icon: Icons.account_circle_rounded,
                text: AppStrings.whatsNewAccount,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(AppStrings.gotIt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text, required this.isDark});

  final IconData icon;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: AppTextStyles.body1(isDark).copyWith(fontSize: 14.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
