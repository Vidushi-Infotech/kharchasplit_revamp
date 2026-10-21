import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Slim sticky header that hosts the 3-tab bar (Expenses / Balances /
/// Activity). Pinned in a NestedScrollView so the group hero card scrolls
/// away while the tabs remain visible at the top.
class GroupStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  GroupStickyTabBarDelegate({
    required this.child,
    required this.isDark,
    this.height = 58,
  });

  final Widget child;
  final bool isDark;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      // Match the screen background so the pinned bar blends in when the
      // hero card has scrolled past, and a 1-px hairline divider separates
      // it from the content below.
      color: AppColors.background(isDark),
      elevation: overlapsContent ? 1 : 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: child),
          Container(
            height: 1,
            color: AppColors.divider(isDark).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(GroupStickyTabBarDelegate oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.isDark != isDark ||
      oldDelegate.height != height;
}
