import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/content_width.dart';
import '../../../components/components.dart';
import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/web/responsive_grid.dart';
import '../../../components/web/web_page.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../state/groups_provider.dart';
import '../widgets/group_grid_card.dart';

enum _BalanceFilter { all, owed, owe, settled }

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  _BalanceFilter _filter = _BalanceFilter.all;
  String _query = '';
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _query = '';
    });
  }

  /// 250 ms debounce on every keystroke. Cancels the previous pending
  /// rebuild and only commits the latest query when typing settles. Cuts
  /// rebuild count from one-per-keystroke down to one-per-pause.
  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = q);
    });
  }

  List<GroupModel> _applyFilters(List<GroupModel> groups) {
    return groups.where((g) {
      final matchesQuery =
          _query.isEmpty || g.name.toLowerCase().contains(_query.toLowerCase());
      final matchesFilter = switch (_filter) {
        _BalanceFilter.all => true,
        _BalanceFilter.owed => g.myBalance > 0,
        _BalanceFilter.owe => g.myBalance < 0,
        _BalanceFilter.settled => g.myBalance == 0,
      };
      return matchesQuery && matchesFilter;
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
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () => ref.read(groupsProvider.notifier).refresh(),
          ),
          data: (allGroups) {
            final visible = _applyFilters(allGroups);
            return RefreshIndicator(
              onRefresh: () => ref.read(groupsProvider.notifier).refresh(),
              child: WebContentColumn(
                child: CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CollapsibleHeader(
                        isDark: isDark,
                        totalCount: allGroups.length,
                        filter: _filter,
                        onFilter: (f) => setState(() => _filter = f),
                        onCreate: () => context.push('/home/create-group'),
                        isSearching: _isSearching,
                        query: _query,
                        searchController: _searchController,
                        searchFocus: _searchFocus,
                        onSearchTap: _openSearch,
                        onSearchClose: _closeSearch,
                        onSearchChanged: _onSearchChanged,
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
                    else if (visible.isEmpty)
                      SliverToBoxAdapter(
                        child: _EmptyResultsCard(isDark: isDark, query: _query),
                      )
                    else
                      SliverPadding(
                        padding: _gridPadding(context),
                        sliver: SliverGrid.builder(
                          gridDelegate: _gridDelegate(context),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final group = visible[index];
                            return GroupGridCard(
                              group: group,
                              onTap: () =>
                                  context.push('/home/groups/${group.id}'),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
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
    required this.isSearching,
    required this.query,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchTap,
    required this.onSearchClose,
    required this.onSearchChanged,
  });

  final bool isDark;
  final int totalCount;
  final _BalanceFilter filter;
  final ValueChanged<_BalanceFilter> onFilter;
  final VoidCallback onCreate;
  final bool isSearching;
  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onSearchTap;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;

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
            child: isSearching
                ? _SearchBar(
                    controller: searchController,
                    focusNode: searchFocus,
                    isDark: isDark,
                    onChanged: onSearchChanged,
                    onClose: onSearchClose,
                  )
                : _TitleRow(
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
        oldDelegate.filter != filter ||
        oldDelegate.isSearching != isSearching ||
        oldDelegate.query != query;
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
            const DonateHeartButton(size: 38, iconSize: 18),
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.search_rounded,
              isDark: isDark,
              onTap: onSearch,
              label: 'Search groups',
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
              ? 'No groups yet'
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
              label: 'Search groups',
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: AppColors.textPrimary(isDark),
            tooltip: 'Close search',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              autofocus: false,
              style: AppTextStyles.body1(isDark).copyWith(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search groups',
                hintStyle: AppTextStyles.body1(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 15,
                ),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.textSecondary(isDark),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
              ),
            ),
          ),
        ],
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

class _EmptyResultsCard extends StatelessWidget {
  const _EmptyResultsCard({required this.isDark, required this.query});

  final bool isDark;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        32,
        20,
        bottomNavReserve(context.widthTier),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 36,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'No groups match this filter'
                : 'No groups match "$query"',
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different filter or search term',
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.errorText(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load groups",
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.body2(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
