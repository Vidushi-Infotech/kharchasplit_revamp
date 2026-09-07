import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../components/web/hoverable.dart';
import '../../../components/web/web_page.dart';
import '../../../components/web/web_page_header.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendsAsync = ref.watch(friendsProvider);

    final isWeb = context.widthTier.isWebTier;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      // The web shell already names the section in the sidebar and the page
      // header below carries the title, so the mobile title bar is redundant.
      appBar: isWeb
          ? null
          : AppBar(
              title: const Text('Friends'),
              elevation: 0,
              backgroundColor: AppColors.surface(isDark),
            ),
      body: friendsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ShimmerList(type: ShimmerListType.friend, itemCount: 6),
        ),
        error: (err, _) => ErrorStateWidget(
          title: "Couldn't load friends",
          message: err.toString(),
          onRetry: () => ref.invalidate(friendsProvider),
        ),
        data: (friends) {
          if (friends.isEmpty) {
            return EmptyStateWidget.noFriends(
              onAddFriend: () => context.push('/home/create-group'),
            );
          }
          final list = ListView.separated(
            padding: EdgeInsets.fromLTRB(16, isWeb ? 0 : 16, 16, 24),
            itemCount: friends.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final f = friends[index];
              final tile = Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: AvatarWidget(
                    imageUrl: f.user.avatarUrl,
                    name: f.user.name,
                    radius: 22,
                  ),
                  title: Text(
                    f.user.name,
                    style: AppTextStyles.body1(isDark)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    f.sharedGroupIds.length == 1
                        ? '1 shared group'
                        : '${f.sharedGroupIds.length} shared groups',
                    style: AppTextStyles.caption(isDark),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  // On web the tap is handled by the hover wrapper so the row
                  // gets a cursor and a focus ring too.
                  onTap: isWeb
                      ? null
                      : () => context.push('/home/friends/${f.user.id}'),
                ),
              );

              if (!isWeb) return tile;
              return Hoverable(
                borderRadius: 12,
                semanticLabel: 'Open ${f.user.name}',
                onTap: () => context.push('/home/friends/${f.user.id}'),
                child: tile,
              );
            },
          );

          if (!isWeb) return list;

          return WebContentColumn(
            width: ContentWidth.reading,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                WebPageHeader(
                  title: 'Friends',
                  subtitle: friends.length == 1
                      ? '1 person you share groups with'
                      : '${friends.length} people you share groups with',
                ),
                const SizedBox(height: 20),
                Expanded(child: list),
              ],
            ),
          );
        },
      ),
    );
  }
}
