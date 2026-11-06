import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/web/web_page.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friend_detail_provider.dart';
import '../state/friends_provider.dart';
import 'friend_add_expense_button.dart';
import 'friend_detail_actions.dart';
import 'friend_detail_header.dart';
import 'friend_detail_top_bar.dart';
import 'friend_shared_expenses.dart';

/// Widest the single-column list grows on standard (600–1100px) screens.
const double _standardMaxWidth = 760;

/// Compact (<600px) and standard (600–1100px): one scroll view — banner,
/// name and balances, action chips, then the month-grouped shared
/// expenses. Standard centres everything below the banner.
class FriendDetailScrollLayout extends ConsumerWidget {
  const FriendDetailScrollLayout({
    super.key,
    required this.friend,
    required this.onBack,
  });

  final FriendBalance friend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width < 600
        ? 0.0
        : math.max(8.0, (width - _standardMaxWidth) / 2);
    return RefreshIndicator(
      // Below the pinned bar so the spinner isn't hidden behind it.
      edgeOffset: kToolbarHeight + MediaQuery.paddingOf(context).top,
      onRefresh: () => ref.read(friendActionsProvider).refresh(friend.user.id),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          FriendDetailSliverBar(friend: friend, onBack: onBack),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FriendDetailHeader(friend: friend),
                  FriendDetailActions(friend: friend),
                ],
              ),
            ),
          ),
          FriendSharedExpensesSlivers(friend: friend, horizontalInset: inset),
        ],
      ),
    );
  }
}

/// Large (>1100px): banner, balances and chips in a left pane; the shared
/// expenses with their Add expense button on the right.
class FriendDetailLargeLayout extends ConsumerWidget {
  const FriendDetailLargeLayout({
    super.key,
    required this.friend,
    required this.onBack,
  });

  final FriendBalance friend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WebContentColumn(
      width: ContentWidth.wide,
      gutter: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: CustomScrollView(
              slivers: [
                FriendDetailSliverBar(friend: friend, onBack: onBack),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FriendDetailHeader(
                        friend: friend,
                        horizontalPadding: 32,
                      ),
                      FriendDetailActions(friend: friend),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                border: Border(
                  left: BorderSide(color: AppColors.divider(isDark)),
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(friendActionsProvider).refresh(friend.user.id),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _PaneHeader(friend: friend)),
                    FriendSharedExpensesSlivers(
                      friend: friend,
                      bottomPadding: 32,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Expenses" title with Add expense — the desktop stand-in for the
/// phone's floating button.
class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.friend});

  final FriendBalance friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                AppStrings.expenses,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary(isDark),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          FriendAddExpenseButton(
            friend: friend,
            style: FriendAddExpenseStyle.pill,
          ),
        ],
      ),
    );
  }
}
