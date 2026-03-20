import 'package:flutter/material.dart';

/// Web layout wrapper with sidebar + content
/// Used for devices > 1100px width
class WebLayout extends StatelessWidget {
  final Widget child;
  final Widget? sidebar;
  final String? title;
  final List<Widget>? actions;

  const WebLayout({
    Key? key,
    required this.child,
    this.sidebar,
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
          // Sidebar
          if (sidebar != null)
            SizedBox(
              width: 280,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: SingleChildScrollView(
                  child: sidebar!,
                ),
              ),
            ),
          // Main content
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.02),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
