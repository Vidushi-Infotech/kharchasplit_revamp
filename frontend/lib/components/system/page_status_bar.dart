import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar icons that suit a plain page background: dark icons in the
/// light theme, light icons in the dark theme. Custom top bars (not
/// [AppBar]) wrap themselves in this; otherwise the light icons from a
/// colored header (the group banner) carry over and vanish on white.
class PageStatusBar extends StatelessWidget {
  const PageStatusBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: child,
    );
  }
}
