import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/groups_provider.dart';
import '../../notifications/state/notifications_inbox_provider.dart';
import '../state/dashboard_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    super.key,
    this.onNotificationsTap,
    this.onOwedTap,
    this.onOweTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onOwedTap;
  final VoidCallback? onOweTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final data = ref.watch(dashboardProvider).value ?? DashboardData.empty;

    final firstName = _firstName(user?.name);
    final greeting = _greetingFor(DateTime.now());

    // The group counts under the pills must reflect ALL of the user's
    // groups, not the recent-5 carousel — otherwise the dashboard's
    // "N groups" caption disagrees with the You're-Owed / You-Owe detail
    // screens (which now read the same full list).
    final allGroups = ref.watch(groupsProvider).value ?? const [];
    final owedCount = allGroups.where((g) => g.myBalance > 0).length;
    final oweCount = allGroups.where((g) => g.myBalance < 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Greeting(
                isDark: isDark,
                greeting: greeting,
                firstName: firstName,
              ),
            ),
            const SizedBox(width: 12),
            _NotificationButton(
              isDark: isDark,
              onTap: onNotificationsTap,
              unreadCount: ref.watch(unreadNotificationsCountProvider),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _BalancePill(
                isDark: isDark,
                label: "You're owed",
                amount: data.youAreOwed,
                groupCount: owedCount,
                isPositive: true,
                onTap: onOwedTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BalancePill(
                isDark: isDark,
                label: 'You owe',
                amount: data.youOwe,
                groupCount: oweCount,
                isPositive: false,
                onTap: onOweTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _firstName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'there';
    return trimmed.split(' ').first;
  }

  String _greetingFor(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.isDark,
    required this.greeting,
    required this.firstName,
  });

  final bool isDark;
  final String greeting;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '$greeting,',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                firstName,
                style: AppTextStyles.headline2(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your money at a glance',
          style: AppTextStyles.body2(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.isDark,
    this.onTap,
    this.unreadCount = 0,
  });

  final bool isDark;
  final VoidCallback? onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final label = hasUnread
        ? 'Notifications, $unreadCount unread'
        : 'Notifications';

    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: AppColors.textPrimary(isDark),
                ),
                if (hasUnread)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.cardBg(isDark),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
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

class _BalancePill extends StatelessWidget {
  const _BalancePill({
    required this.isDark,
    required this.label,
    required this.amount,
    required this.groupCount,
    required this.isPositive,
    this.onTap,
  });

  final bool isDark;
  final String label;
  final double amount;
  final int groupCount;
  final bool isPositive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isPositive ? AppColors.success : AppColors.warning;
    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount.abs());
    final sign = isPositive ? '+' : '-';
    final groupLabel = groupCount == 1 ? 'group' : 'groups';

    final pill = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.06 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$sign$formatted',
              style: AppTextStyles.headline3(isDark).copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$groupCount $groupLabel',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return pill;

    return Semantics(
      button: true,
      label: '$label, $sign$formatted, $groupCount $groupLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: pill,
        ),
      ),
    );
  }
}
