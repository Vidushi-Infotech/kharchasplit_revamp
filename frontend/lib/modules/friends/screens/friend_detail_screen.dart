import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friend_detail_provider.dart';
import '../state/friends_provider.dart';
import '../widgets/friend_detail_actions.dart';
import '../widgets/friend_detail_header.dart';
import '../widgets/friend_group_balances.dart';
import '../widgets/friend_shared_expenses.dart';

/// One friend: overall balance (server ledger), per-group breakdown,
/// Settle up / Remind, and the expenses you share.
class FriendDetailScreen extends ConsumerWidget {
  final String friendId;

  const FriendDetailScreen({super.key, required this.friendId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final friendAsync = ref.watch(friendByIdProvider(friendId));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text(friendAsync.value?.user.name ?? 'Friend'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: friendAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerList(type: ShimmerListType.friend, itemCount: 4),
        ),
        error: (err, _) => ErrorStateWidget(
          title: 'Failed to load friend details',
          message: err.toString(),
          onRetry: () => ref.invalidate(friendsProvider),
        ),
        data: (friend) {
          if (friend == null) {
            // Stale deep link, or nobody you share a group / balance with.
            return EmptyStateWidget(
              icon: '🔍',
              title: 'Friend not found',
              subtitle: "You don't share any groups or balances with "
                  'this person.',
              actionLabel: 'Back to friends',
              onActionPressed: () => context.go('/home/friends'),
            );
          }
          Future<void> refresh() =>
              ref.read(friendActionsProvider).refresh(friendId);
          // Compact < 600 and standard 600–1100 stack everything in one
          // capped column; large > 1100 puts balances beside expenses.
          if (width >= 1100) {
            return _LargeLayout(friend: friend, onRefresh: refresh);
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: _Capped(
              maxWidth: width < 600 ? double.infinity : 720,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ..._summarySlivers(friend),
                  FriendSharedExpensesSlivers(friendId: friendId),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

List<Widget> _summarySlivers(FriendBalance friend) => [
      SliverToBoxAdapter(child: FriendDetailHeader(friend: friend)),
      SliverToBoxAdapter(child: FriendDetailActions(friend: friend)),
      FriendGroupBalancesSliver(friend: friend),
    ];

class _LargeLayout extends StatelessWidget {
  const _LargeLayout({required this.friend, required this.onRefresh});

  final FriendBalance friend;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: CustomScrollView(slivers: _summarySlivers(friend)),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 3,
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [FriendSharedExpensesSlivers(friendId: friend.user.id)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Capped extends StatelessWidget {
  const _Capped({required this.maxWidth, required this.child});
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
