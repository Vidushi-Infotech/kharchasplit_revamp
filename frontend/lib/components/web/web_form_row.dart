import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';

/// Lays fields out in one column on touch layouts and side by side on the web
/// shell.
///
/// A desktop form of eight full-width stacked fields makes the user scroll
/// past whitespace to reach the submit button. Grouping related fields onto a
/// row halves the height without crowding anything.
///
/// Below [Breakpoints.shellWeb] the children are stacked exactly as they were,
/// separated by [spacing], so existing mobile forms are unaffected.
class WebFormRow extends StatelessWidget {
  const WebFormRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.flex,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  }) : assert(children.length > 0, 'WebFormRow needs at least one child.');

  final List<Widget> children;

  /// Gap between fields — horizontal on web, vertical when stacked.
  final double spacing;

  /// Relative widths on web, one entry per child. Defaults to equal columns.
  final List<int>? flex;

  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (!context.widthTier.isWebTier) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }

    assert(
      flex == null || flex!.length == children.length,
      'flex must have one entry per child.',
    );

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(flex: flex?[i] ?? 1, child: children[i]),
        ],
      ],
    );
  }
}

/// Right-aligns form actions on the web and stretches them full width on
/// touch, matching the platform convention on each.
class WebFormActions extends StatelessWidget {
  const WebFormActions({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!context.widthTier.isWebTier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          children[i],
        ],
      ],
    );
  }
}
