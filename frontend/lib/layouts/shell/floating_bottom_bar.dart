import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';

/// Floating bottom navigation bar with an iOS 18-style liquid glass
/// background. Tabs are icon-only with a subtle pill behind the selected
/// one + a small accent dot indicator. The "Create" slot is a raised
/// gradient circle that sits flush in the middle.
class FloatingBottomBar extends StatelessWidget {
  const FloatingBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.fabIndex = 2,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final int fabIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: SizedBox(
        height: 64,
        child: LiquidGlassLayer(
          settings: LiquidGlassSettings(
            thickness: 14,
            blur: 8,
            glassColor: isDark
                ? const Color(0x55101A19)
                : const Color(0x88FFFFFF),
          ),
          child: LiquidGlass(
            shape: const LiquidRoundedSuperellipse(borderRadius: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.30 : 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                child: Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = selectedIndex == index;
                    final isFab = index == fabIndex;
                    return Expanded(
                      child: isFab
                          ? _FabSlot(
                              item: item,
                              onTap: () {
                                // FAB always fires — it's a discrete action
                                // ("create"), not a tab switch.
                                HapticService.instance.tap();
                                onItemSelected(index);
                              },
                            )
                          : _IconSlot(
                              item: item,
                              isSelected: isSelected,
                              isDark: isDark,
                              onTap: () {
                                // Tab switch — selection click only when
                                // actually moving to a new tab.
                                if (!isSelected) {
                                  HapticService.instance.selection();
                                }
                                onItemSelected(index);
                              },
                            ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
}

class _IconSlot extends StatelessWidget {
  const _IconSlot({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.brand;
    final fg = isSelected ? accent : AppColors.textSecondary(isDark);

    final iconWithBadge = item.badgeCount > 0
        ? Badge(
            label: Text('${item.badgeCount}'),
            backgroundColor: AppColors.warning,
            child: Icon(item.icon, size: 22, color: fg),
          )
        : Icon(item.icon, size: 22, color: fg);

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: isDark ? 0.22 : 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: iconWithBadge,
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 12 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FabSlot extends StatelessWidget {
  const _FabSlot({required this.item, required this.onTap});

  final FloatingNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      child: Center(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.tealLight, AppColors.tealDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealDark.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(item.icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
