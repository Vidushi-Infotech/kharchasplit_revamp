import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/group_model.dart';
import '../../groups/widgets/group_detail_banner.dart';
import '../state/friend_detail_view.dart';
import '../../../core/theme/system_ui.dart';
import '../state/friends_provider.dart';

const double _bannerHeight = 140;
const double _avatarOverlap = 32;
const double _avatarSize = 72;

/// A stand-in "direct" group so [GroupBannerArt] draws its teal pattern
/// (direct groups never show a cover photo) — the same art as group detail.
final GroupModel _patternOnly = GroupModel(
  id: '',
  name: '',
  coverEmoji: '',
  members: const [],
  createdAt: DateTime(2000),
  kind: 'direct',
);

/// Collapsing top of friend detail: the teal banner with a back arrow, and
/// the friend's round avatar overlapping its bottom edge. Scrolled up it
/// pins as a teal bar with the friend's name.
class FriendDetailSliverBar extends StatelessWidget {
  const FriendDetailSliverBar({
    super.key,
    required this.friend,
    required this.onBack,
  });

  final FriendBalance friend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.paddingOf(context).top;
    final name = friendDisplayName(friend.user.name);
    return SliverAppBar(
      pinned: true,
      expandedHeight: _bannerHeight + _avatarOverlap,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.brand,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      // Light icons on the teal banner; navigation bar as the page.
      systemOverlayStyle: AppSystemUi.overDarkHeader(
        Theme.of(context).brightness == Brightness.dark,
      ),
      automaticallyImplyLeading: false,
      leading: GlassIconButton.isGlass
          ? Center(
              child: GlassIconButton(
                icon: Icons.arrow_back_rounded,
                sfSymbol: 'chevron.left',
                tooltip: AppStrings.groupBack,
                color: Colors.white,
                onPressed: onBack,
              ),
            )
          : IconButton(
              tooltip: AppStrings.groupBack,
              onPressed: onBack,
              icon: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          final minH = kToolbarHeight + topPad;
          final range = _bannerHeight + _avatarOverlap + topPad - minH;
          // 1 fully expanded → 0 pinned.
          final t = range <= 0
              ? 0.0
              : ((c.maxHeight - minH) / range).clamp(0.0, 1.0);
          final strip = (c.maxHeight - minH).clamp(0.0, _avatarOverlap);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: strip,
                child: Opacity(
                  opacity: (t * 1.4).clamp(0.0, 1.0),
                  child: GroupBannerArt(group: _patternOnly),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: strip,
                child: ColoredBox(color: AppColors.background(isDark)),
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: Opacity(
                  opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                  child: _RingedAvatar(friend: friend, isDark: isDark),
                ),
              ),
              // Name in the pinned bar once the banner is gone.
              Positioned(
                left: 64,
                right: 16,
                top: topPad,
                height: kToolbarHeight,
                child: Opacity(
                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Round avatar with a ring in the page color, so it reads as cut out of
/// the banner.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.friend, required this.isDark});

  final FriendBalance friend;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final user = friend.user;
    return ExcludeSemantics(
      child: Container(
        width: _avatarSize,
        height: _avatarSize,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background(isDark),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: user.isPlaceholder ? 0.6 : 1,
          child: AvatarWidget(
            imageUrl: user.avatarUrl,
            name: friendDisplayName(user.name),
            radius: (_avatarSize - 6) / 2,
          ),
        ),
      ),
    );
  }
}
