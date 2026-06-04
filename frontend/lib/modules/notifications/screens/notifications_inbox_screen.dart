import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/notifications_inbox_provider.dart';

class NotificationsInboxScreen extends ConsumerWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inboxAsync = ref.watch(notificationsInboxProvider);
    final notifier = ref.read(notificationsInboxProvider.notifier);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        onBack: () => context.pop(),
        unreadCount: inboxAsync.value?.unreadCount ?? 0,
        onMarkAllRead: notifier.markAllRead,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 1100 ? 640 : 760,
            ),
            child: RefreshIndicator(
              color: AppColors.tealDark,
              onRefresh: notifier.refresh,
              child: inboxAsync.when(
                loading: () => const _LoadingState(),
                error: (e, _) => _ErrorState(
                  isDark: isDark,
                  message: 'Couldn\'t load notifications',
                  onRetry: notifier.refresh,
                ),
                data: (data) {
                  if (data.items.isEmpty) {
                    return _EmptyState(isDark: isDark);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    itemCount: data.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = data.items[i];
                      return _NotificationCard(
                        item: item,
                        isDark: isDark,
                        onTap: () async {
                          if (!item.isRead) {
                            // Optimistic mark-as-read happens inside the notifier.
                            notifier.markRead(item.id);
                          }
                          NotificationRouter.routeByType(
                            appRouter,
                            item.type,
                            item.data,
                          );
                        },
                      );
                    },
                  );
                },
              ),
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
    required this.onBack,
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  final bool isDark;
  final VoidCallback onBack;
  final int unreadCount;
  final Future<void> Function() onMarkAllRead;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Notifications',
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tealDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasUnread)
                TextButton(
                  onPressed: () => onMarkAllRead(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.tealDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    'Mark all read',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  final NotificationItem item;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(item.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? AppColors.cardBg(isDark)
                : AppColors.tealDark.withValues(alpha: isDark ? 0.10 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead
                  ? AppColors.divider(isDark)
                  : AppColors.tealDark.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _iconForType(item.type),
                  size: 19,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.body1(isDark).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.textPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(item.createdAt),
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 13,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealDark,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'EXPENSE_ADDED':
      case 'EXPENSE_UPDATED':
      case 'EXPENSE_DELETED':
        return Icons.receipt_long_rounded;
      case 'SETTLEMENT_CREATED':
      case 'SETTLEMENT_CONFIRMED':
        return Icons.payments_rounded;
      case 'SETTLEMENT_REMINDER':
        return Icons.alarm_rounded;
      case 'GROUP_INVITE':
        return Icons.group_add_rounded;
      case 'MEMBER_ADDED':
        return Icons.person_add_rounded;
      case 'MEMBER_REMOVED':
      case 'MEMBER_LEFT':
        return Icons.person_remove_rounded;
      case 'GROUP_ARCHIVED':
      case 'GROUP_COMPLETED':
        return Icons.archive_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color _accentForType(String type) {
    switch (type) {
      case 'SETTLEMENT_CREATED':
      case 'SETTLEMENT_CONFIRMED':
        return AppColors.success;
      case 'SETTLEMENT_REMINDER':
        return AppColors.warning;
      case 'GROUP_INVITE':
      case 'MEMBER_ADDED':
        return AppColors.tealDark;
      case 'MEMBER_REMOVED':
      case 'MEMBER_LEFT':
      case 'EXPENSE_DELETED':
        return AppColors.warning;
      default:
        return AppColors.tealDark;
    }
  }

  static String _timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Needs to be scrollable for the RefreshIndicator to work.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      children: [
        Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.tealDark.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 36,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "You're all caught up",
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New activity in your groups will show up here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                height: 1.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 84,
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.isDark,
    required this.message,
    required this.onRetry,
  });

  final bool isDark;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      children: [
        Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => onRetry(),
              child: Text(
                'Retry',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
