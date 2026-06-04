import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/state/haptic_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/notification_prefs_provider.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final pushDisabled = !prefs.pushEnabled;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        title: 'Notifications',
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 1100 ? 640 : 760,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _Intro(isDark: isDark),
                const SizedBox(height: 18),
                _SectionLabel(label: 'CHANNELS', isDark: isDark),
                const SizedBox(height: 8),
                _ToggleGroup(
                  isDark: isDark,
                  items: [
                    _ToggleItem(
                      icon: Icons.notifications_active_rounded,
                      title: 'Push notifications',
                      subtitle: 'Alerts on this device',
                      value: prefs.pushEnabled,
                      onChanged: (v) => notifier
                          .update((p) => p.copyWith(pushEnabled: v)),
                    ),
                    _ToggleItem(
                      icon: Icons.mail_outline_rounded,
                      title: 'Email',
                      subtitle: 'Receipts and important updates',
                      value: prefs.emailEnabled,
                      onChanged: (v) => notifier
                          .update((p) => p.copyWith(emailEnabled: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionLabel(label: 'DEVICE FEEDBACK', isDark: isDark),
                const SizedBox(height: 8),
                _ToggleGroup(
                  isDark: isDark,
                  items: [
                    _ToggleItem(
                      icon: Icons.vibration_rounded,
                      title: 'Haptic feedback',
                      subtitle:
                          'Subtle vibrations when you tap, swipe, or confirm. '
                          'Subject to your phone\'s haptic settings.',
                      value: ref.watch(hapticEnabledProvider),
                      onChanged: (v) =>
                          ref.read(hapticEnabledProvider.notifier).setEnabled(v),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionLabel(label: 'ACTIVITY', isDark: isDark),
                const SizedBox(height: 8),
                _ToggleGroup(
                  isDark: isDark,
                  disabled: pushDisabled,
                  disabledHint: pushDisabled
                      ? 'Enable push notifications to use these.'
                      : null,
                  items: [
                    _ToggleItem(
                      icon: Icons.add_card_rounded,
                      title: 'New expense added',
                      subtitle: 'When someone adds an expense in your group',
                      value: prefs.newExpense,
                      onChanged: (v) =>
                          notifier.update((p) => p.copyWith(newExpense: v)),
                    ),
                    _ToggleItem(
                      icon: Icons.group_add_rounded,
                      title: 'Group invites',
                      subtitle: 'When someone invites you to a group',
                      value: prefs.groupInvite,
                      onChanged: (v) =>
                          notifier.update((p) => p.copyWith(groupInvite: v)),
                    ),
                    _ToggleItem(
                      icon: Icons.attach_money_rounded,
                      title: 'Payments received',
                      subtitle: 'When someone settles up with you',
                      value: prefs.paymentReceived,
                      onChanged: (v) => notifier
                          .update((p) => p.copyWith(paymentReceived: v)),
                    ),
                    _ToggleItem(
                      icon: Icons.alarm_rounded,
                      title: 'Settlement reminders',
                      subtitle: 'Gentle nudge when balances stay open',
                      value: prefs.settlementReminder,
                      onChanged: (v) => notifier
                          .update((p) => p.copyWith(settlementReminder: v)),
                    ),
                    _ToggleItem(
                      icon: Icons.alternate_email_rounded,
                      title: 'Comments & mentions',
                      subtitle: 'When you\'re tagged in a note',
                      value: prefs.commentMention,
                      onChanged: (v) => notifier
                          .update((p) => p.copyWith(commentMention: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionLabel(label: 'SUMMARIES', isDark: isDark),
                const SizedBox(height: 8),
                _ToggleGroup(
                  isDark: isDark,
                  items: [
                    _ToggleItem(
                      icon: Icons.calendar_view_week_rounded,
                      title: 'Weekly summary',
                      subtitle: 'A digest of your spending every week',
                      value: prefs.weeklySummary,
                      onChanged: (v) =>
                          notifier.update((p) => p.copyWith(weeklySummary: v)),
                    ),
                    _ToggleItem(
                      icon: Icons.calendar_month_rounded,
                      title: 'Monthly summary',
                      subtitle: 'A month-end report with insights',
                      value: prefs.monthlySummary,
                      onChanged: (v) => notifier
                          .update((p) => p.copyWith(monthlySummary: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionLabel(label: 'FROM KHARCHASPLIT', isDark: isDark),
                const SizedBox(height: 8),
                _ToggleGroup(
                  isDark: isDark,
                  items: [
                    _ToggleItem(
                      icon: Icons.new_releases_outlined,
                      title: 'Product updates',
                      subtitle: 'New features and improvements',
                      value: prefs.productUpdates,
                      onChanged: (v) => notifier
                          .update((p) => p.copyWith(productUpdates: v)),
                    ),
                    _ToggleItem(
                      icon: Icons.local_offer_outlined,
                      title: 'Tips & offers',
                      subtitle: 'Personalized tips and occasional offers',
                      value: prefs.tipsAndOffers,
                      onChanged: (v) =>
                          notifier.update((p) => p.copyWith(tipsAndOffers: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'You can change these anytime.',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
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

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.isDark,
    required this.title,
    required this.onBack,
  });

  final bool isDark;
  final String title;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background(isDark),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Back',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onBack,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.tealDark.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 18,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose what you want to hear about — and how.',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
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

class _ToggleItem {
  const _ToggleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
}

class _ToggleGroup extends StatelessWidget {
  const _ToggleGroup({
    required this.isDark,
    required this.items,
    this.disabled = false,
    this.disabledHint,
  });

  final bool isDark;
  final List<_ToggleItem> items;
  final bool disabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _ToggleRow(item: items[i], isDark: isDark, disabled: disabled),
                if (i < items.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color:
                          AppColors.divider(isDark).withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (disabled && disabledHint != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.textSecondary(isDark),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    disabledHint!,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.item,
    required this.isDark,
    required this.disabled,
  });

  final _ToggleItem item;
  final bool isDark;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = disabled ? false : item.value;
    final fg = disabled
        ? AppColors.textSecondary(isDark)
        : AppColors.textPrimary(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                HapticService.instance.selection();
                item.onChanged(!item.value);
              },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  color: disabled
                      ? AppColors.textSecondary(isDark)
                      : AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.body1(isDark).copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch.adaptive(
                value: effectiveValue,
                onChanged: disabled ? null : item.onChanged,
                activeThumbColor: AppColors.tealDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

