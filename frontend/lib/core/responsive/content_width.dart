import 'breakpoints.dart';

/// How wide a page's content column is allowed to grow.
///
/// Replaces the `screenWidth < 1100 ? 640 : 760` expression that was
/// copy-pasted across fourteen screens with five different value pairs. A page
/// declares its *intent* — "this is a form", "this is a feed" — and the width
/// follows from the tier.
///
/// The compact and medium values match what those screens already used, so
/// nothing below [Breakpoints.shellWeb] changes.
enum ContentWidth {
  /// Single-column forms: login, settle, add personal expense. Wide forms are
  /// harder to scan, not easier — this stays narrow at every tier.
  form(atCompact: double.infinity, atMedium: 460, atExpanded: 520, atWide: 520),

  /// Long-form reading and single-stream feeds: policy text, activity,
  /// notifications, settlement history.
  reading(
    atCompact: double.infinity,
    atMedium: 640,
    atExpanded: 820,
    atWide: 900,
  ),

  /// The default for content pages — detail views, profile, lists that carry
  /// secondary structure.
  standard(
    atCompact: double.infinity,
    atMedium: 720,
    atExpanded: 1080,
    atWide: 1180,
  ),

  /// Grids, dashboards and two-pane layouts that genuinely use the width.
  wide(
    atCompact: double.infinity,
    atMedium: 720,
    atExpanded: 1200,
    atWide: 1320,
  ),

  /// Opt out of capping entirely. For screens that manage their own panes.
  full(
    atCompact: double.infinity,
    atMedium: double.infinity,
    atExpanded: double.infinity,
    atWide: double.infinity,
  );

  const ContentWidth({
    required this.atCompact,
    required this.atMedium,
    required this.atExpanded,
    required this.atWide,
  });

  final double atCompact;
  final double atMedium;
  final double atExpanded;
  final double atWide;

  double forTier(WidthTier tier) => switch (tier) {
    WidthTier.compact => atCompact,
    WidthTier.medium => atMedium,
    WidthTier.expanded => atExpanded,
    WidthTier.wide => atWide,
  };
}

/// Horizontal page gutters, scaled per tier.
///
/// Compact keeps the 20px the mobile screens already use.
class PageGutter {
  const PageGutter._();

  static double forTier(WidthTier tier) => switch (tier) {
    WidthTier.compact => 20,
    WidthTier.medium => 24,
    WidthTier.expanded => 32,
    WidthTier.wide => 40,
  };
}

/// Bottom padding a scrollable needs to clear the mobile floating navigation
/// bar.
///
/// Only the mobile shell draws that bar, so inside the web shell the reserve
/// is pure dead space at the foot of every list.
///
/// The tablet tier keeps the original value even though its rail is vertical
/// too: the approved tablet presentation is out of scope here, and holding the
/// line at [Breakpoints.shellWeb] keeps the guarantee that nothing below it
/// changes.
double bottomNavReserve(WidthTier tier, {double compact = 110}) =>
    tier.isWebTier ? 40 : compact;

/// The spacing scale used by web layout code.
///
/// Existing mobile widgets keep their own values — this is not a migration
/// target, it is here so new web layout code stops inventing numbers.
class Space {
  const Space._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}
