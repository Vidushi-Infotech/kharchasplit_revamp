import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../state/group_display.dart';
import '../state/group_detail_provider.dart';
import 'export_group_menu.dart';
import 'group_detail_banner.dart';
import 'group_detail_cover.dart';

/// Height of the cover banner, and how far the group avatar hangs below it.
const double groupBannerHeight = 140;
const double _avatarOverlap = 28;
const double _avatarSize = 64;

/// Collapsing top of group detail: the cover banner with back, ⚙ settings
/// and ⋮ over it, and the square group avatar overlapping its bottom
/// edge. Scrolled up it pins as a teal bar with the group name.
class GroupDetailSliverBar extends StatelessWidget {
  const GroupDetailSliverBar({
    super.key,
    required this.detail,
    required this.myId,
    required this.onBack,
    required this.onSettings,
    required this.onRecurring,
    required this.onMenuExport,
  });

  final GroupDetail detail;
  final String? myId;
  final VoidCallback onBack;

  /// Null hides ⚙ (direct groups have no settings).
  final VoidCallback? onSettings;

  /// Null hides "Recurring expenses" in ⋮ (flag off).
  final VoidCallback? onRecurring;

  /// A value picked from the export entries of ⋮ (Excel / CSV / PDF).
  final ValueChanged<String> onMenuExport;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.paddingOf(context).top;
    final title = detail.group.displayTitle(myId);
    return SliverAppBar(
      pinned: true,
      expandedHeight: groupBannerHeight + _avatarOverlap,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.brand,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      leading: _BarIcon(
        icon: Icons.arrow_back_rounded,
        label: AppStrings.groupBack,
        onTap: onBack,
      ),
      actions: [
        if (onSettings != null)
          _BarIcon(
            icon: Icons.settings_outlined,
            label: AppStrings.groupSettings,
            onTap: onSettings!,
          ),
        _menu(isDark),
        const SizedBox(width: 4),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          final minH = kToolbarHeight + topPad;
          final range = groupBannerHeight + _avatarOverlap + topPad - minH;
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
                  child: GroupBannerArt(group: detail.group),
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
                  child: GroupBannerAvatar(
                    size: _avatarSize,
                    child: GroupDetailCover(
                      group: detail.group,
                      myId: myId,
                      size: _avatarSize - 6,
                      borderRadius: 12,
                      emojiFontSize: 30,
                      fallbackIconColor: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ),
              // Group name in the pinned bar once the banner is gone.
              Positioned(
                left: 64,
                right: 112,
                top: topPad,
                height: kToolbarHeight,
                child: Opacity(
                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
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

  Widget _menu(bool isDark) {
    return PopupMenuButton<String>(
      tooltip: AppStrings.groupMoreOptions,
      color: AppColors.cardBg(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider(isDark)),
      ),
      icon: const _IconDisc(icon: Icons.more_vert_rounded),
      onSelected: (value) => value == 'recurring'
          ? onRecurring?.call()
          : value == 'settings'
          ? onSettings?.call()
          : onMenuExport(value),
      itemBuilder: (_) => [
        if (onSettings != null)
          _item(
            'settings',
            Icons.settings_outlined,
            AppStrings.groupSettings,
            isDark,
          ),
        if (onRecurring != null)
          _item(
            'recurring',
            Icons.repeat_rounded,
            AppStrings.recurringExpenses,
            isDark,
          ),
        ...buildGroupExportMenuItems(isDark, includeExcel: true),
      ],
    );
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label,
    bool isDark,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textPrimary(isDark)),
        const SizedBox(width: 10),
        Flexible(child: Text(label)),
      ],
    ),
  );
}

/// White icon on a dark disc so it reads on any banner photo.
class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: _IconDisc(icon: icon),
    );
  }
}

class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}
