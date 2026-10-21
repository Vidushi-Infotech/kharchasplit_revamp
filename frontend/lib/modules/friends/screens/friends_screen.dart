import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../components/web/web_page.dart';
import '../../../components/web/web_page_header.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      // The web shell already names the section in the sidebar and the page
      // header below carries the title, so the mobile title bar is redundant.
      appBar: isWeb
          ? null
          : AppBar(
              title: const Text(AppStrings.friends),
              elevation: 0,
              backgroundColor: AppColors.surface(isDark),
            ),
      body: friendsAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.all(gutter),
          child: const ShimmerList(type: ShimmerListType.friend, itemCount: 6),
        ),
        error: (err, _) => ErrorStateWidget(
          title: "Couldn't load friends",
          message: err.toString(),
          onRetry: () => ref.invalidate(friendsProvider),
        ),
        data: (friends) {
          if (friends.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: c.maxHeight,
                    child: EmptyStateWidget.noFriends(
                      onAddFriend: () => context.push('/home/create-group'),
                    ),
                  ),
                ),
              ),
            );
          }
          final list = _FriendsList(
            padding: EdgeInsets.fromLTRB(gutter, isWeb ? 0 : 16, gutter, 24),
            hoverable: isWeb,
            isDark: isDark,
          );

          if (!isWeb) {
            return RefreshIndicator(onRefresh: () => _refresh(ref), child: list);
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
      ),
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

/// Summary header + lazily built friend rows (after the hide-settled filter).
class _FriendsList extends ConsumerWidget {
  const _FriendsList({
    required this.padding,
    required this.hoverable,
    required this.isDark,
  });

  final EdgeInsets padding;
  final bool hoverable;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleFriendsProvider).value ?? const [];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      // +1 for the header; +1 for the "everyone hidden" note when filtered
      // down to nothing.
      itemCount: 1 + (visible.isEmpty ? 1 : visible.length),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) return const FriendsSummaryHeader();
        if (visible.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              AppStrings.youAreAllSettledUp,
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(isDark)
                  .copyWith(color: AppColors.textSecondary(isDark)),
            ),
          );
        }
        final f = visible[index - 1];
        return FriendListTile(
          friend: f,
          hoverable: hoverable,
          onTap: () => context.push('/home/friends/${f.user.id}'),
        );
      },
    );
  }
}
