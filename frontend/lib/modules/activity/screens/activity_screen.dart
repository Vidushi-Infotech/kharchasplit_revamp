import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/activity_model.dart';
import '../state/activity_feed_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final filter = ref.watch(activityFilterProvider);
    final feedAsync = ref.watch(filteredActivityFeedProvider);
    final allActivities = ref.watch(activityFeedProvider).value ?? const [];
    final unreadCount = allActivities.where((a) => !a.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        onBack: () => context.pop(),
        unreadCount: unreadCount,
        onMarkAllRead: () =>
            ref.read(activityFeedProvider.notifier).markAllAsRead(),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 1100 ? 640 : 760,
            ),
            child: Column(
              children: [
                _FilterChips(
                  isDark: isDark,
                  selected: filter,
                  onSelect: (f) =>
                      ref.read(activityFilterProvider.notifier).state = f,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.tealDark,
                    onRefresh: () =>
                        ref.read(activityFeedProvider.notifier).refresh(),
                    child: feedAsync.when(
                      loading: () => const _LoadingState(),
                      error: (_, __) => _ErrorState(
                        isDark: isDark,
                        onRetry: () =>
                            ref.read(activityFeedProvider.notifier).refresh(),
                      ),
                      data: (activities) {
                        if (activities.isEmpty) {
                          return _EmptyState(isDark: isDark);
                        }
                        return _ActivityList(
                          activities: activities,
                          isDark: isDark,
                          onMarkRead: (a) {
                            if (!a.isRead) {
                              ref
                                  .read(activityFeedProvider.notifier)
                                  .markAsRead(a.id);
                            }
                          },
                          onOpen: (a) {
                            if (!a.isRead) {
                              ref
                                  .read(activityFeedProvider.notifier)
                                  .markAsRead(a.id);
                            }
                            _routeForActivity(context, a);
                          },
                        );
                      },
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

  void _routeForActivity(BuildContext context, ActivityModel a) {
    final groupId = a.group?.id;
    if (a.expense != null) {
      context.push('/expense/${a.expense!.id}');
      return;
    }
    if (groupId != null && groupId.isNotEmpty) {
      context.push('/home/groups/$groupId');
    }
  }
}

// --------------------------------------------------------------------------
// Top bar
// --------------------------------------------------------------------------

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
  final VoidCallback onMarkAllRead;

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
                        'Activity',
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
                  onPressed: onMarkAllRead,
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

// --------------------------------------------------------------------------
// Filter chips
// --------------------------------------------------------------------------

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.isDark,
    required this.selected,
    required this.onSelect,
  });

  final bool isDark;
  final ActivityFilter selected;
  final ValueChanged<ActivityFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    const entries = <(ActivityFilter, String, IconData)>[
      (ActivityFilter.all, 'All', Icons.dashboard_rounded),
      (ActivityFilter.expenses, 'Expenses', Icons.receipt_long_rounded),
      (ActivityFilter.settlements, 'Settled', Icons.payments_rounded),
      (ActivityFilter.groups, 'Groups', Icons.group_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final (filter, label, icon) = entries[i];
            return _Chip(
              isDark: isDark,
              label: label,
              icon: icon,
              selected: selected == filter,
              onTap: () => onSelect(filter),
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.isDark,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final bool isDark;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.tealDark;
    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
        : AppColors.cardBg(isDark);
    final borderColor = selected
        ? accent.withValues(alpha: 0.55)
        : AppColors.divider(isDark);
    final fg = selected ? accent : AppColors.textSecondary(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.body2(isDark).copyWith(
                  fontSize: 12,
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Activity list (grouped by date)
// --------------------------------------------------------------------------

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.activities,
    required this.isDark,
    required this.onMarkRead,
    required this.onOpen,
  });

  final List<ActivityModel> activities;
  final bool isDark;
  final ValueChanged<ActivityModel> onMarkRead;
  final ValueChanged<ActivityModel> onOpen;

  @override
  Widget build(BuildContext context) {
    // Group activities by date.
    final grouped = <String, List<ActivityModel>>{};
    for (final a in activities) {
      final key = DateFormatter.groupHeaderDate(a.timestamp);
      grouped.putIfAbsent(key, () => []).add(a);
    }
    final keys = grouped.keys.toList();

    // The shell's floating bottom bar (extendBody: true) overlays the bottom
    // of this list. Pad past it (bar footprint ≈ 76 + safe-area inset) so the
    // last rows aren't hidden behind it.
    final bottomClear = MediaQuery.paddingOf(context).bottom + 88;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottomClear),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final dateKey = keys[i];
        final items = grouped[dateKey]!;
        return Padding(
          padding: EdgeInsets.only(bottom: i == keys.length - 1 ? 0 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  dateKey.toUpperCase(),
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    fontSize: 11,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider(isDark)),
                ),
                child: Column(
                  children: [
                    for (int j = 0; j < items.length; j++) ...[
                      _ActivityRow(
                        activity: items[j],
                        isDark: isDark,
                        onMarkRead: () => onMarkRead(items[j]),
                        onOpen: () => onOpen(items[j]),
                      ),
                      if (j < items.length - 1)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          height: 1,
                          color: AppColors.divider(
                            isDark,
                          ).withValues(alpha: 0.6),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------------
// Activity row (single entry inside a date group)
// --------------------------------------------------------------------------

class _ActivityRow extends StatefulWidget {
  const _ActivityRow({
    required this.activity,
    required this.isDark,
    required this.onMarkRead,
    required this.onOpen,
  });

  final ActivityModel activity;
  final bool isDark;
  final VoidCallback onMarkRead;
  final VoidCallback onOpen;

  @override
  State<_ActivityRow> createState() => _ActivityRowState();

  // Static helpers used by detail/icon widgets below.
  static IconData _iconFor(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
      case ActivityType.expenseEdited:
        return Icons.receipt_long_rounded;
      case ActivityType.expenseDeleted:
        return Icons.delete_outline_rounded;
      case ActivityType.settled:
        return Icons.payments_rounded;
      case ActivityType.groupCreated:
        return Icons.group_add_rounded;
      case ActivityType.memberAdded:
        return Icons.person_add_alt_1_rounded;
      case ActivityType.memberRemoved:
        return Icons.person_remove_alt_1_rounded;
      case ActivityType.commentAdded:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  static Color _accentFor(ActivityType type) {
    switch (type) {
      case ActivityType.settled:
        return AppColors.success;
      case ActivityType.expenseDeleted:
      case ActivityType.memberRemoved:
        return AppColors.warning;
      case ActivityType.groupCreated:
      case ActivityType.memberAdded:
      case ActivityType.commentAdded:
      case ActivityType.expenseAdded:
      case ActivityType.expenseEdited:
        return AppColors.tealDark;
    }
  }
}

class _ActivityRowState extends State<_ActivityRow>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  void _toggleAndMaybeMarkRead() {
    setState(() => _expanded = !_expanded);
    // Tap is mark-as-read only when expanding. Navigation is a separate
    // explicit action via the "Open" button inside the expanded view.
    if (_expanded) widget.onMarkRead();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final isDark = widget.isDark;
    final accent = _ActivityRow._accentFor(activity.type);
    final icon = _ActivityRow._iconFor(activity.type);
    final actorName = activity.actorUser?.name.trim() ?? '';
    final body = activity.description;
    final unread = !activity.isRead;
    final hasDetails =
        body.isNotEmpty ||
        actorName.isNotEmpty ||
        (activity.group != null && activity.group!.name.isNotEmpty);

    return Semantics(
      button: true,
      label: 'Activity: ${activity.typeName}',
      expanded: _expanded,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Row tap always toggles expand; if there's nothing to expand
          // (no body / no meta), fall back to "Open" so the row still
          // does something useful.
          onTap: hasDetails ? _toggleAndMaybeMarkRead : widget.onOpen,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            color: unread
                ? AppColors.tealDark.withValues(alpha: isDark ? 0.08 : 0.04)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Always-visible compact header (uniform 44px content row).
                SizedBox(
                  height: 44,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, size: 18, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          activity.typeName,
                          style: AppTextStyles.body1(isDark).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary(isDark),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.relativeTime(activity.timestamp),
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (unread)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.tealDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasDetails)
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                    ],
                  ),
                ),
                // Expansion content
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(48, 6, 0, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (body.isNotEmpty)
                          Text(
                            body,
                            style: AppTextStyles.body2(isDark).copyWith(
                              color: AppColors.textSecondary(isDark),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        if (actorName.isNotEmpty ||
                            (activity.group != null &&
                                activity.group!.name.isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (actorName.isNotEmpty)
                                _Pill(
                                  isDark: isDark,
                                  icon: Icons.person_outline_rounded,
                                  text: actorName,
                                ),
                              if (activity.group != null &&
                                  activity.group!.name.isNotEmpty)
                                _Pill(
                                  isDark: isDark,
                                  icon: Icons.group_outlined,
                                  text: activity.group!.name,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        // Action row: "Open" button to take the user deeper.
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onOpen,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Open',
                                    style: AppTextStyles.body2(isDark).copyWith(
                                      color: AppColors.tealDark,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: AppColors.tealDark,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Subtle pill chip used for actor/group meta on the row.
class _Pill extends StatelessWidget {
  const _Pill({required this.isDark, required this.icon, required this.text});

  final bool isDark;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary(isDark)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              text,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Empty / Loading / Error states
// --------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        80,
        20,
        MediaQuery.paddingOf(context).bottom + 88,
      ),
      children: [
        Column(
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tealDark.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timeline_rounded,
                size: 36,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No activity yet',
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Expenses, settlements and group events will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark), height: 1.4),
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
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.paddingOf(context).bottom + 88,
      ),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            width: 90,
            height: 11,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.isDark, required this.onRetry});

  final bool isDark;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        80,
        20,
        MediaQuery.paddingOf(context).bottom + 88,
      ),
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
              'Couldn\'t load activity',
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w600),
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
