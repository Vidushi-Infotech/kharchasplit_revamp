import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../components/headers/glass_large_title.dart';
import '../../../components/list/list_components.dart';
import '../../../components/web/web_page.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/group_model.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../profile/widgets/email_verify_strip.dart';
import '../state/groups_list_view.dart';
import '../state/groups_provider.dart';
import '../widgets/group_row_card.dart';
import '../widgets/groups_archived_section.dart';
import '../widgets/groups_list_header.dart';
import '../widgets/groups_list_states.dart';

/// Groups tab (the home tab), Splitwise-style: title bar, "Overall, you
/// are owed ₹X" with a filter menu, then one flat row per group. Archived
/// groups open from the footer, next to "Start a new group".
///
/// Compact is full width; standard (600–1100) and large (> 1100) center
/// the same list in a reading-width column.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(groupsProvider);
    // iOS 26: large title that collapses into the button row on scroll.
    final glass = GlassIconButton.isGlass;
    final top = glass ? GlassLargeTitleFrame.topInset(context) : 0.0;
    final Widget topBar = glass ? SizedBox(height: top) : const GroupsTopBar();

    final body = groupsAsync.when(
      loading: () => Column(
        children: [
          topBar,
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: ShimmerList(type: ShimmerListType.group, itemCount: 6),
            ),
          ),
        ],
      ),
      error: (err, _) => Column(
        children: [
          topBar,
          Expanded(
            child: GroupsErrorState(
              message: err.toString(),
              onRetry: () => ref.read(groupsProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
      data: (groups) => RefreshIndicator(
        color: AppColors.brand,
        edgeOffset: top,
        // Dashboard refresh reloads the groups list first, so one call
        // refreshes both the overall line and the rows.
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: _GroupsList(groups: groups, topBar: topBar),
      ),
    );

    if (glass) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        body: GlassLargeTitleFrame(
          title: AppStrings.groups,
          actions: groupsHeaderActions(context),
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: WebContentColumn(
          width: ContentWidth.reading,
          gutter: false,
          applyBelowWebTier: true,
          child: body,
        ),
      ),
    );
  }
}

class _GroupsList extends ConsumerWidget {
  const _GroupsList({required this.groups, required this.topBar});

  final List<GroupModel> groups;

  /// [GroupsTopBar], or the space under the iOS 26 large-title header.
  final Widget topBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(groupsListFilterProvider);
    final archivedOpen = ref.watch(showArchivedGroupsProvider);
    final people = ref.watch(groupPersonBalancesProvider);

    final active = groups.where((g) => !g.isArchived).toList();
    final visible = filterGroups(active, filter);
    final archived = filterGroups(groups.where((g) => g.isArchived), filter);
    void createGroup() => context.push('/home/create-group');

    Widget rows(List<GroupModel> list) => SliverList.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final g = list[i];
        return GroupRowCard(
          group: g,
          people: people[g.id] ?? const [],
          showDivider: i < list.length - 1,
          onTap: () => context.push('/home/groups/${g.id}'),
        );
      },
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: topBar),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmailVerifyStrip(bottomSpacing: 8),
          ),
        ),
        const SliverToBoxAdapter(child: GroupsOverallHeader()),
        if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget.noGroups(onCreateGroup: createGroup),
          )
        else ...[
          if (active.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: NoActiveGroupsCard(onCreate: createGroup),
              ),
            )
          else if (visible.isEmpty)
            SliverToBoxAdapter(
              child: GroupsEmptyResultsCard(isDark: isDark, query: ''),
            ),
          rows(visible),
          if (archivedOpen && archived.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: MonthSectionHeader(
                AppStrings.archivedGroupsCount(archived.length),
              ),
            ),
            rows(archived),
          ],
          SliverToBoxAdapter(
            child: ListFooterActions(
              note: filter == GroupsListFilter.all
                  ? null
                  : AppStrings.groupsFilteredNote,
              actions: [
                if (archived.isNotEmpty)
                  ListFooterAction(
                    label: archivedOpen
                        ? AppStrings.hideArchivedGroups
                        : AppStrings.showArchivedGroups(archived.length),
                    icon: Icons.archive_outlined,
                    onTap: ref.read(showArchivedGroupsProvider.notifier).toggle,
                  ),
                ListFooterAction(
                  label: AppStrings.startNewGroup,
                  icon: Icons.group_add_outlined,
                  onTap: createGroup,
                ),
              ],
            ),
          ),
        ],
        // Room for the floating "Add expense" button over the last row.
        SliverToBoxAdapter(
          child: SizedBox(
            height: shellBottomReserve(context, context.widthTier, compact: 88),
          ),
        ),
      ],
    );
  }
}
