import '../../../core/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/web/responsive_grid.dart';
import '../../../components/web/web_page.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../profile/widgets/email_verify_strip.dart';
import '../state/groups_provider.dart';
import '../widgets/group_grid_card.dart';
import '../widgets/groups_archived_section.dart';
import '../widgets/groups_list_states.dart';
import '../widgets/groups_notifications_button.dart';
import '../widgets/overall_balance_card.dart';

enum _BalanceFilter { all, owed, owe, settled }

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  _BalanceFilter _filter = _BalanceFilter.all;
  bool _showArchived = false;

  /// The search button opens the global search (expenses, groups and
  /// friends) — it replaced the old in-place group-name filter.
  void _openSearch() => context.push('/search');

  List<GroupModel> _applyFilters(List<GroupModel> groups) {
    return groups.where((g) {
      return switch (_filter) {
        _BalanceFilter.all => true,
        _BalanceFilter.owed => g.myBalance > 0,
        _BalanceFilter.owe => g.myBalance < 0,
        _BalanceFilter.settled => g.myBalance == 0,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: groupsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ShimmerList(type: ShimmerListType.group, itemCount: 6),
          ),
          error: (err, _) => GroupsErrorState(
            message: err.toString(),
            onRetry: () => ref.read(groupsProvider.notifier).refresh(),
          ),
          data: (allGroups) {
            // Archived groups sit in a collapsed section at the end; the
            // filters apply to both halves.
            final active = allGroups.where((g) => !g.isArchived).toList();
            final visible = _applyFilters(active);
            final visibleArchived =
                _applyFilters(allGroups.where((g) => g.isArchived).toList());
            final hasArchived = visibleArchived.isNotEmpty;
            final archivedOpen = _showArchived;
            final gridPad = _gridPadding(context);
            final side = gridPad.left;
            return RefreshIndicator(
              // Dashboard refresh reloads the groups list first, so one call
              // refreshes both the overall card and the grid.
              onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
              child: WebContentColumn(
                child: CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CollapsibleHeader(
                        isDark: isDark,
                        totalCount: active.length,
                        filter: _filter,
                        onFilter: (f) => setState(() => _filter = f),
                        onCreate: () => context.push('/home/create-group'),
                        onSearchTap: _openSearch,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, 12, side, 0),
                      sliver: const SliverToBoxAdapter(
                        child: Column(
                          children: [
                            EmailVerifyStrip(bottomSpacing: 12),
                            OverallBalanceCard(),
                          ],
                        ),
                      ),
                    ),
                    if (allGroups.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateWidget.noGroups(
                          onCreateGroup: () =>
                              context.push('/home/create-group'),
                        ),
                      )
                    else if (active.isEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(side, 16, side, 8),
                        sliver: SliverToBoxAdapter(
                          child: NoActiveGroupsCard(
                            onCreate: () => context.push('/home/create-group'),
                          ),
                        ),
                      )
                    else if (visible.isEmpty && !hasArchived)
                      SliverToBoxAdapter(
                        child: GroupsEmptyResultsCard(
                          isDark: isDark,
                          query: '',
                        ),
                      ),
                    if (visible.isNotEmpty)
                      _gridSliver(
                        context,
                        visible,
                        hasArchived ? gridPad.copyWith(bottom: 4) : gridPad,
                      ),
                    if (hasArchived) ...[
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(side, 8, side, 0),
                        sliver: SliverToBoxAdapter(
                          child: ArchivedGroupsToggle(
                            count: visibleArchived.length,
                            expanded: archivedOpen,
                            onTap: () =>
                                setState(() => _showArchived = !archivedOpen),
                          ),
                        ),
                      ),
                      if (archivedOpen)
                        _gridSliver(
                          context,
                          visibleArchived,
                          gridPad.copyWith(top: 4),
                        )
                      else
                        SliverToBoxAdapter(
                          child: SizedBox(height: gridPad.bottom),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _gridSliver(
    BuildContext context,
    List<GroupModel> groups,
    EdgeInsets padding,
  ) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid.builder(
        gridDelegate: _gridDelegate(context),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return GroupGridCard(
            group: group,
            onTap: () => context.push('/home/groups/${group.id}'),
          );
        },
      ),
    );
  }

  /// Below the web shell breakpoint this is the original two-column grid,
  /// unchanged. Inside the web shell the column count follows the available
  /// width instead, so a desktop display shows a row of readable cards rather
  /// than two stretched to ~800px each.
  SliverGridDelegate _gridDelegate(BuildContext context) {
    if (!context.widthTier.isWebTier) {
      return const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      );
    }
    // A fixed height rather than an aspect ratio: cards should not grow taller
    // every time the window gets wider.
    return ResponsiveGrid.delegate(
      maxItemExtent: 280,
      itemHeight: 176,
      spacing: 14,
    );
  }

  /// The 110px bottom reserve exists for the mobile floating navigation bar.
  /// The web shell has no such bar, so on desktop it is just dead space.
  EdgeInsets _gridPadding(BuildContext context) => context.widthTier.isWebTier
      ? const EdgeInsets.fromLTRB(0, 4, 0, 40)
      : const EdgeInsets.fromLTRB(20, 12, 20, 110);
}

class _CollapsibleHeader extends SliverPersistentHeaderDelegate {
  _CollapsibleHeader({
    required this.isDark,
    required this.totalCount,
    required this.filter,
    required this.onFilter,
    required this.onCreate,
    required this.onSearchTap,
  });

  final bool isDark;
  final int totalCount;
  final _BalanceFilter filter;
  final ValueChanged<_BalanceFilter> onFilter;
  final VoidCallback onCreate;
  final VoidCallback onSearchTap;

  // Tight enough to sit just below the status bar (no big empty band on
  // top), still tall enough for the 28pt headline + the GROUPS overline.
  static const double _expandedExtent = 84;
  static const double _collapsedExtent = 56;
  static const double _filterStripHeight = 42;

  @override
  double get minExtent => _collapsedExtent + _filterStripHeight;
  @override
  double get maxExtent => _expandedExtent + _filterStripHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = _expandedExtent - _collapsedExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);

    return Material(
      color: AppColors.background(isDark),
      child: Column(
        children: [
          Expanded(
            child: _TitleRow(
              isDark: isDark,
              totalCount: totalCount,
              onSearch: onSearchTap,
              onCreate: onCreate,
              collapseProgress: t,
            ),
          ),
          SizedBox(
            height: _filterStripHeight,
            child: _FilterRow(
              current: filter,
              isDark: isDark,
              onSelected: onFilter,
            ),
          ),
          Container(
            height: 1,
            color: AppColors.divider(isDark).withValues(alpha: t * 0.8),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CollapsibleHeader oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.totalCount != totalCount ||
        oldDelegate.filter != filter;
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.isDark,
    required this.totalCount,
    required this.onSearch,
    required this.onCreate,
    required this.collapseProgress,
  });

  final bool isDark;
  final int totalCount;
  final VoidCallback onSearch;
  final VoidCallback onCreate;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) {
    // Cross-fade between expanded and collapsed layouts. They share the same
    // available height (animated by SliverPersistentHeader) so we just toggle
    // opacity to morph the visible content.
    final expandedOpacity = (1 - collapseProgress * 1.6).clamp(0.0, 1.0);
    final collapsedOpacity = ((collapseProgress - 0.4) / 0.6).clamp(0.0, 1.0);

    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            OverflowBox(
              alignment: Alignment.bottomLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Opacity(
                opacity: expandedOpacity,
                child: IgnorePointer(
                  ignoring: collapseProgress > 0.5,
                  child: _ExpandedTitle(
                    isDark: isDark,
                    totalCount: totalCount,
                    onSearch: onSearch,
                    onCreate: onCreate,
                  ),
                ),
              ),
            ),
            OverflowBox(
              alignment: Alignment.bottomLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Opacity(
                opacity: collapsedOpacity,
                child: IgnorePointer(
                  ignoring: collapseProgress < 0.5,
                  child: _CollapsedTitle(
                    isDark: isDark,
                    totalCount: totalCount,
                    onSearch: onSearch,
                    onCreate: onCreate,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedTitle extends StatelessWidget {
  const _ExpandedTitle({
    required this.isDark,
    required this.totalCount,
    required this.onSearch,
    required this.onCreate,
  });

  final bool isDark;
  final int totalCount;
  final VoidCallback onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    // Show a back button ONLY when this screen was pushed onto a stack
    // (i.e. reached from the dashboard's 'Your Groups >' link). When the
    // user lands here via the bottom-nav Groups tab, canPop is false and
    // no chevron is shown — Groups is a root destination in that case.
    final canPop = Navigator.of(context).canPop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          children: [
            if (canPop) ...[
              _IconAction(
                icon: Icons.arrow_back_rounded,
                isDark: isDark,
                onTap: () => Navigator.of(context).pop(),
                label: 'Back',
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                'GROUPS',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  fontSize: 11,
                ),
              ),
            ),
            const GroupsNotificationsButton(),
            const SizedBox(width: 4),
            const DonateHeartButton(size: 38, iconSize: 18),
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.search_rounded,
              isDark: isDark,
              onTap: onSearch,
              label: AppStrings.search,
            ),
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.add_rounded,
              isDark: isDark,
              onTap: onCreate,
              label: 'Create group',
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          totalCount == 0
              ? AppStrings.noActiveGroups
              : '$totalCount ${totalCount == 1 ? 'group' : 'groups'}',
          style: AppTextStyles.headline2(isDark).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.1,
            fontSize: 28,
          ),
        ),
      ],
    );
  }
}

class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({
    required this.isDark,
    required this.totalCount,
    required this.onSearch,
    required this.onCreate,
  });

  final bool isDark;
  final int totalCount;
  final VoidCallback onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    // Same canPop guard as in _ExpandedTitle: back chevron only when
    // pushed onto a stack, never when reached via the bottom tab.
    final canPop = Navigator.of(context).canPop();
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            if (canPop) ...[
              _IconAction(
                icon: Icons.arrow_back_rounded,
                isDark: isDark,
                onTap: () => Navigator.of(context).pop(),
                label: 'Back',
                compact: true,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                totalCount == 0 ? 'Groups' : 'Groups · $totalCount',
                style: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _IconAction(
              icon: Icons.search_rounded,
              isDark: isDark,
              onTap: onSearch,
              label: AppStrings.search,
              compact: true,
            ),
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.add_rounded,
              isDark: isDark,
              onTap: onCreate,
              label: 'Create group',
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 38.0;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBg(isDark),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Icon(
              icon,
              size: compact ? 17 : 18,
              color: AppColors.textPrimary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.isDark,
    required this.onSelected,
  });

  final _BalanceFilter current;
  final bool isDark;
  final ValueChanged<_BalanceFilter> onSelected;

  static const _options = <(_BalanceFilter, String)>[
    (_BalanceFilter.all, 'All'),
    (_BalanceFilter.owed, 'Owed'),
    (_BalanceFilter.owe, 'Owe'),
    (_BalanceFilter.settled, 'Settled'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _options.map((opt) {
          final (value, label) = opt;
          final selected = current == value;
          return Padding(
            padding: const EdgeInsets.only(right: 18),
            child: _FilterButton(
              label: label,
              isSelected: selected,
              isDark: isDark,
              onTap: () => onSelected(value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected
        ? AppColors.textPrimary(isDark)
        : AppColors.textSecondary(isDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.body2(isDark).copyWith(
                color: fg,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 2,
              width: isSelected ? 18 : 0,
              decoration: BoxDecoration(
                color: AppColors.tealDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
