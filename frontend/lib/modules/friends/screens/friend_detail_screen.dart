import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friends_provider.dart';
import '../widgets/friend_add_expense_button.dart';
import '../widgets/friend_detail_layouts.dart';

/// One friend, laid out like group detail: teal banner with the friend's
/// avatar, the overall balance and per-group lines, Settle up / Remind…
/// chips, and the expenses you share as a month-grouped flat list, with an
/// extended Add expense button.
class FriendDetailScreen extends ConsumerWidget {
  final String friendId;

  const FriendDetailScreen({super.key, required this.friendId});

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home/friends');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final friendAsync = ref.watch(friendByIdProvider(friendId));
    final friend = friendAsync.value;

    if (friend == null) {
      // Loading, failed, or not a friend (stale deep link): a plain bar so
      // there is always a way back.
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.background(isDark),
          leading: BackButton(onPressed: () => _back(context)),
          title: const Text(AppStrings.friendFallbackTitle),
        ),
        body: friendAsync.isLoading && !friendAsync.hasValue
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerList(type: ShimmerListType.friend, itemCount: 4),
              )
            : friendAsync.hasError
                ? ErrorStateWidget(
                    title: AppStrings.friendLoadError,
                    message: friendAsync.error.toString(),
                    onRetry: () => ref.invalidate(friendsProvider),
                  )
                : EmptyStateWidget(
                    icon: '🔍',
                    title: AppStrings.friendNotFound,
                    subtitle: AppStrings.friendNotFoundHint,
                    actionLabel: AppStrings.backToFriends,
                    onActionPressed: () => context.go('/home/friends'),
                  ),
      );
    }

    final large = width >= 1100;
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: large
          ? FriendDetailLargeLayout(
              friend: friend,
              onBack: () => _back(context),
            )
          : FriendDetailScrollLayout(
              friend: friend,
              onBack: () => _back(context),
            ),
      // On web / desktop Add expense sits in the list pane header instead.
      floatingActionButton: context.widthTier.isWebTier || large
          ? null
          : FriendAddExpenseButton(friend: friend),
    );
  }
}
