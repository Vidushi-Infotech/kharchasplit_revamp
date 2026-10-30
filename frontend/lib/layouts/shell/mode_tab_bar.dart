import 'package:flutter/material.dart';

import '../../components/buttons/glass_surface.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/state/app_mode.dart';
import '../../core/theme/app_colors.dart';
import 'glass_shell_bar.dart' show useGlassShell;

/// One bottom tab. A [modeSwitch] item isn't a tab: it switches to the
/// other "app" (Groups ↔ Personal) and is drawn apart from the tabs.
class ShellNavItem {
  const ShellNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.modeSwitch = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool modeSwitch;
}

/// The bottom tab bar of both modes: a Liquid Glass capsule on iOS 26+, a
/// flat Material bar elsewhere. [selectedIndex] is the tab that's open
/// (null when none is, e.g. a page pushed over the tabs).
class ModeTabBar extends StatelessWidget {
  const ModeTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<ShellNavItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  void _tap(int i) {
    final item = items[i];
    if (!item.modeSwitch && i != selectedIndex) {
      HapticService.instance.selection();
    }
    onSelect(i);
  }

  @override
  Widget build(BuildContext context) => useGlassShell
      ? _GlassBar(items: items, selected: selectedIndex, onTap: _tap)
      : _MaterialBar(items: items, selected: selectedIndex, onTap: _tap);
}

/// The mode switch for a NavigationRail (tablets), at the rail's bottom.
class ModeSwitchRailButton extends StatelessWidget {
  const ModeSwitchRailButton({
    super.key,
    required this.to,
    required this.onPressed,
  });

  final AppMode to;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final personal = to == AppMode.personal;
    final label = personal ? AppStrings.personal : AppStrings.groups;
    return Semantics(
      button: true,
      label: personal ? AppStrings.switchToPersonal : AppStrings.switchToGroups,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeSwitchIcon(
                icon: personal
                    ? Icons.account_balance_wallet_rounded
                    : Icons.groups_rounded,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mode switch's icon: the target mode's icon in a tinted circle with a
/// small swap badge, so it reads as "switch", not as another tab.
class _ModeSwitchIcon extends StatelessWidget {
  const _ModeSwitchIcon({required this.icon, this.size = 22});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size + 14,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 10,
            height: size + 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brand.withValues(alpha: isDark ? 0.28 : 0.14),
            ),
            child: Icon(icon, size: size - 2, color: AppColors.brand),
          ),
          Positioned(
            right: -1,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand,
                border: Border.all(
                  color: AppColors.background(isDark),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialBar extends StatelessWidget {
  const _MaterialBar({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  final List<ShellNavItem> items;
  final int? selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // NavigationBar needs a selection; with none open, highlight nothing by
    // pointing at the mode switch, which never draws as selected.
    final switchIndex = items.indexWhere((i) => i.modeSwitch);
    final shown = selected ?? (switchIndex >= 0 ? switchIndex : 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider(isDark), width: 0.6),
        ),
      ),
      child: NavigationBar(
        height: 64,
        selectedIndex: shown,
        backgroundColor: AppColors.surface(isDark),
        surfaceTintColor: Colors.transparent,
        indicatorColor: items[shown].modeSwitch
            ? Colors.transparent
            : AppColors.brand.withValues(alpha: isDark ? 0.25 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: onTap,
        destinations: [
          for (final item in items)
            item.modeSwitch
                ? NavigationDestination(
                    icon: _ModeSwitchIcon(icon: item.icon),
                    selectedIcon: _ModeSwitchIcon(icon: item.icon),
                    label: item.label,
                    tooltip: item.label,
                  )
                : NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(
                      item.selectedIcon,
                      color: AppColors.brand,
                    ),
                    label: item.label,
                  ),
        ],
      ),
    );
  }
}

/// iOS 26 style: a floating Liquid Glass capsule with a bubble that slides
/// to the open tab; the mode switch sits at the end after a hairline.
class _GlassBar extends StatelessWidget {
  const _GlassBar({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  final List<ShellNavItem> items;
  final int? selected;
  final ValueChanged<int> onTap;

  static const double _height = 62;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final idle = AppColors.textPrimary(isDark);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom - 6 : 12),
      child: SizedBox(
        height: _height,
        child: GlassSurface(
          circle: false,
          radius: _height / 2,
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth / items.length;
                final sel = selected;
                return Stack(
                  children: [
                    if (sel != null && !items[sel].modeSwitch)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        left: w * sel,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: isDark ? 0.14 : 0.07),
                            borderRadius: BorderRadius.circular(_height / 2),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _GlassTab(
                              item: items[i],
                              selected: i == sel,
                              color: i == sel ? AppColors.brand : idle,
                              onTap: () => onTap(i),
                              divider: items[i].modeSwitch && i > 0,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTab extends StatelessWidget {
  const _GlassTab({
    required this.item,
    required this.selected,
    required this.color,
    required this.onTap,
    required this.divider,
  });

  final ShellNavItem item;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: divider
                ? Border(
                    left: BorderSide(
                      color: AppColors.divider(isDark),
                      width: 0.8,
                    ),
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.modeSwitch)
                _ModeSwitchIcon(icon: item.icon, size: 20)
              else
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: selected ? 1.08 : 1.0,
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 24,
                    color: color,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected || item.modeSwitch
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: item.modeSwitch ? AppColors.brand : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
