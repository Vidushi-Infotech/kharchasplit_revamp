import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../components/headers/glass_large_title.dart';
import '../../../components/list/list_components.dart';
import '../../../components/web/web_page.dart';
import '../../../components/web/web_page_header.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/friend_list_tile.dart';
import '../widgets/friends_summary_header.dart';

/// Friends tab: overall balance header, then every friend with what they
/// owe you / you owe them across all groups (server ledger).
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendsAsync = ref.watch(friendsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = context.widthTier.isWebTier;
    // Compact < 600 / standard 600–1100 / large > 1100.
    final gutter = width < 600 ? 16.0 : (width < 1100 ? 24.0 : 32.0);

    // iOS 26 (phone/tablet tiers): large title that collapses into the
    // button row on scroll.
    final glass = GlassIconButton.isGlass && !isWeb;
    final top = glass ? GlassLargeTitleFrame.topInset(context) : 0.0;
    final actions = <Widget>[
      // Global search (expenses, groups, friends).
      GlassIconButton(
        icon: Icons.search_rounded,
        sfSymbol: 'magnifyingglass',
        tooltip: 'Search',
        onPressed: () => context.push('/search'),
      ),
      if (!glass) const GlassGap(),
      GlassIconButton(
        icon: Icons.person_add_alt_1_rounded,
        sfSymbol: 'person.badge.plus',
        tooltip: AppStrings.addFriend,
        onPressed: () => showAddFriendSheet(context),
      ),
    ];

    final body = friendsAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.all(gutter).copyWith(top: gutter + top),
        child: const ShimmerList(type: ShimmerListType.friend, itemCount: 6),
      ),
      error: (err, _) => Padding(
        padding: EdgeInsets.only(top: top),
        child: ErrorStateWidget(
          title: "Couldn't load friends",
          message: err.toString(),
          onRetry: () => ref.invalidate(friendsProvider),
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return RefreshIndicator(
            edgeOffset: top,
            onRefresh: () => _refresh(ref),
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: top),
                child: SizedBox(
                  height: c.maxHeight - top,
                  child: EmptyStateWidget.noFriends(
                    onAddFriend: () => showAddFriendSheet(context),
                  ),
                ),
              ),
            ),
          );
        }
        // Rows are flat and full-bleed; the bottom reserve keeps the
        // floating "Add expense" button off the footer.
        final list = _FriendsList(
          padding: EdgeInsets.only(
            top: top,
            bottom: shellBottomReserve(context, context.widthTier, compact: 88),
          ),
          isDark: isDark,
        );

        if (!isWeb) {
          // Standard (600–1100): same list, centered.
          return RefreshIndicator(
            edgeOffset: top,
            onRefresh: () => _refresh(ref),
            child: WebContentColumn(
              width: ContentWidth.reading,
              gutter: false,
              applyBelowWebTier: true,
              child: list,
            ),
          );
        }

        return WebContentColumn(
          width: ContentWidth.reading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              WebPageHeader(
                title: AppStrings.friends,
                subtitle: friends.length == 1
                    ? '1 person'
                    : '${friends.length} people',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => showAddFriendSheet(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(AppStrings.addFriend),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: list,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (glass) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        body: GlassLargeTitleFrame(
          title: AppStrings.friends,
          leading: GlassBackButton.appBarLeading(context),
          actions: actions,
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      // The web shell already names the section in the sidebar and the page
      // header below carries the title, so the mobile title bar is redundant.
      appBar: isWeb
          ? null
          : AppBar(
              title: const Text(AppStrings.friends),
              centerTitle: false,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: AppColors.background(isDark),
              leading: GlassBackButton.appBarLeading(context),
              actions: [...actions, const GlassGap(width: 8)],
            ),
      body: body,
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(friendsProvider);
    try {
      await ref.read(friendsProvider.future);
    } catch (_) {
      // Shown by the error branch.
    }
  }
}

/// Summary header, lazily built flat friend rows (after the hide-settled
/// filter) and the "Add more friends" footer.
class _FriendsList extends ConsumerWidget {
  const _FriendsList({required this.padding, required this.isDark});

  final EdgeInsets padding;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleFriendsProvider).value ?? const [];
    // Header + rows (or the "everyone hidden" note) + footer.
    final rowCount = visible.isEmpty ? 1 : visible.length;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: rowCount + 2,
      itemBuilder: (context, index) {
        if (index == 0) return const FriendsSummaryHeader();
        if (index == rowCount + 1) {
          return ListFooterActions(
            actions: [
              ListFooterAction(
                label: AppStrings.addMoreFriends,
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => showAddFriendSheet(context),
              ),
            ],
          );
        }
        if (visible.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              AppStrings.youAreAllSettledUp,
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
          );
        }
        final f = visible[index - 1];
        return FriendListTile(
          friend: f,
          showDivider: index < visible.length,
          onTap: () => context.push('/home/friends/${f.user.id}'),
        );
      },
    );
  }
}
