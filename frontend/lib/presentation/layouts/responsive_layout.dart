import 'package:flutter/material.dart';
import '../../core/responsive/responsive_utils.dart';
import '../../layouts/mobile/mobile_layout.dart';
import '../../layouts/tablet/tablet_layout.dart';
import '../../layouts/web/web_layout.dart';

/// Responsive layout widget that automatically selects layout based on screen size
///
/// Breakpoints:
/// - Mobile: < 600px (Bottom navigation)
/// - Tablet: 600-1100px (Side navigation)
/// - Web: > 1100px (Sidebar + content)
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final Widget? sideWidget;
  final Widget? bottomWidget;
  final String? title;
  final List<Widget>? actions;
  final bool showAppBar;

  const ResponsiveLayout({
    Key? key,
    required this.child,
    this.sideWidget,
    this.bottomWidget,
    this.title,
    this.actions,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return MobileLayout(
        title: title,
        actions: actions,
        showAppBar: showAppBar,
        bottomNavigationBar: bottomWidget,
        child: child,
      );
    } else if (context.isTablet) {
      return TabletLayout(
        title: title,
        actions: actions,
        sideNavigation: sideWidget,
        child: child,
      );
    } else {
      // Web layout
      return WebLayout(
        title: title,
        actions: actions,
        sidebar: sideWidget,
        child: child,
      );
    }
  }
}
