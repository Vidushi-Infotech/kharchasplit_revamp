import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendsAsync = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Friends'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final f = friends[index];
              return Card(
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
                  onTap: () => context.push('/home/friends/${f.user.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
