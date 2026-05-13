import 'package:flutter/material.dart';

/// Mobile layout wrapper with bottom navigation
/// Used for devices < 600px width
class MobileLayout extends StatelessWidget {
  final Widget child;
  final Widget? bottomNavigationBar;
  final bool showAppBar;
  final String? title;
  final List<Widget>? actions;

  const MobileLayout({
    Key? key,
    required this.child,
    this.bottomNavigationBar,
    this.showAppBar = true,
    this.title,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: title != null ? Text(title!) : null,
              elevation: 0,
              actions: actions,
            )
          : null,
      body: SafeArea(
        child: child,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
