import 'package:flutter/material.dart';

/// Tablet layout wrapper with side navigation
/// Used for devices 600px - 1100px width
class TabletLayout extends StatelessWidget {
  final Widget child;
  final Widget? sideNavigation;
  final String? title;
  final List<Widget>? actions;

  const TabletLayout({
    Key? key,
    required this.child,
    this.sideNavigation,
    this.title,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        elevation: 0,
        actions: actions,
      ),
      body: Row(
        children: [
          // Side navigation
          if (sideNavigation != null)
            SizedBox(
              width: 250,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: sideNavigation!,
              ),
            ),
          // Main content
          Expanded(
            child: SafeArea(
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
