import 'package:flutter/widgets.dart';

/// Single source of truth for width-based layout decisions.
///
/// Two things are deliberately separate here:
///
/// 1. **Shell breakpoints** ([shellTablet], [shellWeb]) decide which app shell
///    renders — bottom bar, navigation rail, or sidebar. These values are the
///    ones the router has always used and they must not move: changing them
///    changes which shell a tablet gets, which is a regression on the approved
///    mobile/tablet UI.
///
/// 2. **Content tiers** ([WidthTier]) decide how a page lays out *inside*
///    whichever shell it got. The two web-only tiers ([WidthTier.expanded] and
///    [WidthTier.wide]) only ever apply at widths that already resolve to the
///    web shell, so no code path reachable below [shellWeb] changes behaviour.
class Breakpoints {
  const Breakpoints._();

  /// At and above this width the tablet shell (navigation rail) takes over
  /// from the mobile shell (floating bottom bar).
  static const double shellTablet = 600;

  /// At and above this width the web shell (fixed sidebar) takes over from
  /// the tablet shell.
  static const double shellWeb = 1100;

  /// Inside the web shell, the point where a large desktop display can carry
  /// wider content and an extra grid column.
  static const double wide = 1440;
}

/// Layout tier derived from the available width.
///
/// [compact] and [medium] describe the already-approved mobile and tablet
/// experiences — code branching on them should keep doing exactly what it did
/// before. [expanded] and [wide] are the web-only tiers.
enum WidthTier {
  compact,
  medium,
  expanded,
  wide;

  static WidthTier fromWidth(double width) {
    if (width < Breakpoints.shellTablet) return WidthTier.compact;
    if (width < Breakpoints.shellWeb) return WidthTier.medium;
    if (width < Breakpoints.wide) return WidthTier.expanded;
    return WidthTier.wide;
  }

  /// True for the two tiers that render inside the web shell.
  bool get isWebTier => this == WidthTier.expanded || this == WidthTier.wide;

  /// True below the tablet shell breakpoint.
  bool get isCompact => this == WidthTier.compact;

  /// Pick a value per tier. [expanded] falls back to [medium] and [wide] falls
  /// back to [expanded], so callers only specify the tiers they care about.
  T pick<T>({required T compact, T? medium, T? expanded, T? wide}) {
    final m = medium ?? compact;
    final e = expanded ?? m;
    return switch (this) {
      WidthTier.compact => compact,
      WidthTier.medium => m,
      WidthTier.expanded => e,
      WidthTier.wide => wide ?? e,
    };
  }
}

extension WidthTierContext on BuildContext {
  /// Layout tier for the current media width.
  ///
  /// Prefer a [LayoutBuilder] when a widget sits inside a constrained column
  /// (a sidebar, a two-pane split) — the window width is the wrong question
  /// there. Use this for page-level decisions.
  WidthTier get widthTier => WidthTier.fromWidth(MediaQuery.sizeOf(this).width);

  /// True only inside the web shell (>= [Breakpoints.shellWeb]).
  ///
  /// Named for the layout, not the platform: a narrow browser window is not
  /// a web layout, and a wide tablet is not either.
  bool get isWebLayout => widthTier.isWebTier;
}
