import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../outbox/state/outbox_provider.dart';
import 'export_my_expenses_action.dart';

/// "Tools" rows near the top of the Account tab. Personal expenses and
/// Reports used to be primary tabs; with the Splitwise-style tab bar they
/// live here as pushed pages (both get a back arrow).
///
/// Styled to match the settings list on the Account screen (label + card
/// of icon rows with dividers).
class AccountShortcutsSection extends ConsumerWidget {
  const AccountShortcutsSection({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsynced = ref.watch(unsyncedCountProvider);
    final rows = <_ShortcutRow>[
      // Changes made offline that aren't on the server yet.
      if (unsynced > 0)
        _ShortcutRow(
          icon: Icons.cloud_upload_outlined,
          label: AppStrings.unsyncedChangesCount(unsynced),
          isDark: isDark,
          onTap: () => context.push('/home/profile/unsynced'),
        ),
      _ShortcutRow(
        icon: Icons.account_balance_wallet_outlined,
        label: AppStrings.personalExpenses,
        isDark: isDark,
        onTap: () => context.push('/home/personal'),
      ),
      _ShortcutRow(
        icon: Icons.bar_chart_rounded,
        label: AppStrings.reports,
        isDark: isDark,
        onTap: () => context.push('/reports'),
      ),
      _ShortcutRow(
        icon: Icons.file_download_outlined,
        label: AppStrings.exportMyExpensesCsv,
        isDark: isDark,
        onTap: () => exportMyExpensesCsv(context, ref),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'TOOLS',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1)
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
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                    icon,
                    size: 17,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
