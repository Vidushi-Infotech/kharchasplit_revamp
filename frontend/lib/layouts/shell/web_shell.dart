import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'shell_state.dart';

/// A destination in the web sidebar.
class _NavDest {
  const _NavDest({
    required this.icon,
    required this.label,
    required this.location,
    required this.matches,
  });

  final IconData icon;
  final String label;
  final String location;

  /// Path prefixes that should light this destination up, so a detail page
  /// keeps its section highlighted.
  final List<String> matches;

  bool isActive(String path) =>
      matches.any((m) => path == m || path.startsWith('$m/'));
}

const _primaryNav = <_NavDest>[
  _NavDest(
    icon: Icons.home_rounded,
    label: 'Home',
    location: '/home/dashboard',
    matches: ['/home/dashboard', '/home/owed-to-me', '/home/i-owe'],
  ),
  _NavDest(
    icon: Icons.group_rounded,
    label: 'Groups',
    location: '/home/groups',
    matches: ['/home/groups', '/home/create-group'],
  ),
  _NavDest(
    icon: Icons.account_balance_wallet_rounded,
    label: 'Personal',
    location: '/home/personal',
    matches: ['/home/personal'],
  ),
  _NavDest(
    icon: Icons.people_alt_rounded,
    label: 'Friends',
    location: '/home/friends',
    matches: ['/home/friends'],
  ),
  _NavDest(
    icon: Icons.notifications_rounded,
    label: 'Activity',
    location: '/home/activity',
    matches: ['/home/activity', '/home/notifications'],
  ),
  _NavDest(
    icon: Icons.bar_chart_rounded,
    label: 'Reports',
    location: '/reports',
    matches: ['/reports'],
  ),
];

const _profileDest = _NavDest(
  icon: Icons.person_rounded,
  label: 'Profile',
  location: '/home/profile',
  matches: ['/home/profile'],
);

/// Sidebar shell for the web layout.
///
/// Active state is derived from the current route rather than from the shared
/// [selectedNavIndexProvider]: that provider is also written by the mobile and
/// tablet shells, which map different destinations onto the same integers, so
/// resizing the window across the shell breakpoint used to leave the wrong
/// item highlighted. Deriving from the route also keeps the highlight correct
/// through deep links and browser Back/Forward.
class WebShell extends ConsumerWidget {
  const WebShell({super.key, required this.child});

  final Widget child;

  /// Below this width the sidebar collapses to an icon rail so the content
  /// column keeps a usable share of a small laptop screen.
  static const double _railBreakpoint = 1280;

  static const double _expandedWidth = 240;
  static const double _railWidth = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = ref.watch(unreadActivityCountProvider);
    final path = GoRouterState.of(context).uri.path;
    final collapsed = MediaQuery.sizeOf(context).width < _railBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: Row(
        children: [
          _Sidebar(
            isDark: isDark,
            collapsed: collapsed,
            path: path,
            unreadCount: unreadCount,
            width: collapsed ? _railWidth : _expandedWidth,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.isDark,
    required this.collapsed,
    required this.path,
    required this.unreadCount,
    required this.width,
  });

  final bool isDark;
  final bool collapsed;
  final String path;
  final int unreadCount;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(right: BorderSide(color: AppColors.divider(isDark))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Brand(isDark: isDark, collapsed: collapsed),
            _AddExpenseButton(isDark: isDark, collapsed: collapsed),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final dest in _primaryNav)
                    _NavItem(
                      dest: dest,
                      isDark: isDark,
                      collapsed: collapsed,
                      isSelected: dest.isActive(path),
                      badge: dest.label == 'Activity' && unreadCount > 0
                          ? '$unreadCount'
                          : null,
                    ),
                ],
              ),
            ),
            Divider(color: AppColors.divider(isDark), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _NavItem(
                dest: _profileDest,
                isDark: isDark,
                collapsed: collapsed,
                isSelected: _profileDest.isActive(path),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.isDark, required this.collapsed});

  final bool isDark;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.brand, AppColors.tealDark]),
      ),
      child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 19),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        collapsed ? 0 : 18,
        18,
        collapsed ? 0 : 18,
        14,
      ),
      child: collapsed
          ? Center(
              child: Tooltip(message: 'Kharcha Split', child: mark),
            )
          : Row(
              children: [
                mark,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kharcha Split',
                    style: AppTextStyles.headline3(
                      isDark,
                    ).copyWith(fontSize: 19, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The web equivalent of the mobile shell's centre FAB. Without it the desktop
/// layout has no primary create action at all.
class _AddExpenseButton extends StatelessWidget {
  const _AddExpenseButton({required this.isDark, required this.collapsed});

  final bool isDark;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    void go() => context.go('/add-expense');

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Tooltip(
          message: 'Add expense',
          child: SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: go,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Icon(Icons.add_rounded, size: 22),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: go,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add expense'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.dest,
    required this.isDark,
    required this.collapsed,
    required this.isSelected,
    this.badge,
  });

  final _NavDest dest;
  final bool isDark;
  final bool collapsed;
  final bool isSelected;
  final String? badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final selected = widget.isSelected;

    final fg = selected
        ? AppColors.brand
        : (_hovered
              ? AppColors.textPrimary(isDark)
              : AppColors.textSecondary(isDark));

    final bg = selected
        ? AppColors.brand.withValues(alpha: 0.14)
        : (_hovered
              ? AppColors.textPrimary(isDark).withValues(alpha: 0.05)
              : Colors.transparent);

    Widget content = Container(
      height: 42,
      margin: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 14 : 12,
        vertical: 3,
      ),
      padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: widget.collapsed
          ? Center(child: _icon(fg))
          : Row(
              children: [
                _icon(fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.dest.label,
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: selected ? AppColors.brand : fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badge != null) _badge(),
              ],
            ),
    );

    if (widget.collapsed) {
      content = Tooltip(message: widget.dest.label, child: content);
    }

    return Semantics(
      selected: selected,
      button: true,
      label: widget.dest.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.go(widget.dest.location),
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      ),
    );
  }

  Widget _icon(Color color) {
    final icon = Icon(widget.dest.icon, color: color, size: 21);
    if (!widget.collapsed || widget.badge == null) return icon;
    // Collapsed rail has no room for a pill, so the count becomes a dot.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -2,
          top: -1,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFD32F2F),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      widget.badge!,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
