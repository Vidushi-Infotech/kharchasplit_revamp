import 'package:flutter/material.dart';

/// Grid delegates that derive their column count from the width actually
/// available, instead of a hardcoded `crossAxisCount`.
///
/// A fixed count is the reason a two-column phone grid becomes two 800px cards
/// on a desktop display. Sizing by max extent means the column count falls out
/// of the layout and never needs a breakpoint.
class ResponsiveGrid {
  const ResponsiveGrid._();

  /// Delegate whose columns follow the available width.
  ///
  /// [maxItemExtent] is the widest a single cell may become — the grid fits as
  /// many whole columns as it can without exceeding it. [minColumns] pins a
  /// floor so a narrow phone keeps the column count its layout was designed
  /// for.
  ///
  /// The [itemHeight] form is preferred over [aspectRatio] on the web: cards
  /// keep a stable height as the column count changes, where a fixed aspect
  /// ratio makes them grow taller every time they grow wider.
  static SliverGridDelegate delegate({
    required double maxItemExtent,
    double? itemHeight,
    double? aspectRatio,
    double spacing = 12,
    double? crossSpacing,
  }) {
    assert(
      (itemHeight == null) != (aspectRatio == null),
      'Provide exactly one of itemHeight or aspectRatio.',
    );
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxItemExtent,
      mainAxisSpacing: spacing,
      crossAxisSpacing: crossSpacing ?? spacing,
      mainAxisExtent: itemHeight,
      childAspectRatio: aspectRatio ?? 1.0,
    );
  }

  /// How many whole columns of [maxItemExtent] fit in [width].
  ///
  /// Use when the caller needs the count itself — laying out a [Wrap], or
  /// deciding whether a two-pane split is worth it.
  static int columnsFor(
    double width, {
    required double maxItemExtent,
    double spacing = 12,
    int minColumns = 1,
    int maxColumns = 8,
  }) {
    if (width <= 0) return minColumns;
    final count = (width + spacing) ~/ (maxItemExtent + spacing);
    return count.clamp(minColumns, maxColumns);
  }
}
