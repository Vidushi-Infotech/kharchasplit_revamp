import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/content_width.dart';
import '../../core/theme/app_colors.dart';
import 'web_page_header.dart';

/// Constrains and gutters a page's content according to its declared width
/// intent, and supplies the web page header.
///
/// On compact and medium tiers this is close to a pass-through: the content
/// width is unconstrained (or capped at the same value the screen already
/// used), no header is inserted, and the screen's own AppBar or sliver header
/// stays in charge. Everything header-shaped only appears inside the web
/// shell.
///
/// Screens that need slivers should use [WebPage.slivers]; screens with a
/// simple box body should use the default constructor.
class WebPage extends StatelessWidget {
  const WebPage({
    super.key,
    required this.child,
    this.width = ContentWidth.standard,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.breadcrumbs = const [],
    this.onBack,
    this.headerBottom,
    this.scrollable = true,
    this.padTop = true,
  }) : slivers = null,
       assert(
         title != null || breadcrumbs.length == 0,
         'Breadcrumbs need a title to sit above.',
       );

  /// Sliver form. [child] is ignored; [slivers] are placed inside the same
  /// constrained column, with the header prepended as a sliver on web.
  const WebPage.slivers({
    super.key,
    required List<Widget> this.slivers,
    this.width = ContentWidth.standard,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.breadcrumbs = const [],
    this.onBack,
    this.headerBottom,
    this.padTop = true,
  }) : child = const SizedBox.shrink(),
       scrollable = false;

  final Widget child;
  final List<Widget>? slivers;
  final ContentWidth width;

  /// Shown only inside the web shell. Leave null to keep the screen's own
  /// header at every tier.
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Crumb> breadcrumbs;
  final VoidCallback? onBack;
  final Widget? headerBottom;

  /// Wrap [child] in a scroll view. Turn off when the child manages its own
  /// scrolling (a ListView, a two-pane split with independent panes).
  final bool scrollable;

  /// Adds the top gutter above the header. Turn off for pages whose first
  /// element supplies its own top spacing.
  final bool padTop;

  @override
  Widget build(BuildContext context) {
    final tier = context.widthTier;
    final maxWidth = width.forTier(tier);
    final gutter = PageGutter.forTier(tier);
    final showHeader = tier.isWebTier && title != null;

    if (slivers != null) {
      return _ConstrainedSlivers(
        maxWidth: maxWidth,
        gutter: gutter,
        header: showHeader ? _header(context, gutter) : null,
        slivers: slivers!,
      );
    }

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          if (padTop) SizedBox(height: gutter),
          _header(context, 0),
          SizedBox(height: gutter),
        ],
        child,
      ],
    );

    body = Padding(
      padding: EdgeInsets.symmetric(horizontal: showHeader ? gutter : 0),
      child: body,
    );

    if (maxWidth.isFinite) {
      body = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: body,
        ),
      );
    }

    if (scrollable) {
      body = SingleChildScrollView(child: body);
    }

    return body;
  }

  Widget _header(BuildContext context, double horizontalPad) => Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPad),
    child: WebPageHeader(
      title: title!,
      subtitle: subtitle,
      actions: actions,
      breadcrumbs: breadcrumbs,
      onBack: onBack,
      bottom: headerBottom,
    ),
  );
}

class _ConstrainedSlivers extends StatelessWidget {
  const _ConstrainedSlivers({
    required this.maxWidth,
    required this.gutter,
    required this.header,
    required this.slivers,
  });

  final double maxWidth;
  final double gutter;
  final Widget? header;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final content = CustomScrollView(
      slivers: [
        if (header != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, gutter),
            sliver: SliverToBoxAdapter(child: header),
          ),
        ...slivers,
      ],
    );

    if (!maxWidth.isFinite) return content;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

/// Centres and caps a subtree at the width its page declares, and adds the
/// tier's horizontal gutter.
///
/// Use this to constrain a screen that already owns its own scroll view — a
/// [CustomScrollView] with a pinned header, a [ListView] with its own
/// controller — where wrapping in [WebPage] would take that ownership away.
///
/// Below the web shell breakpoint it is a pass-through by default, so the
/// screen's existing mobile layout is untouched.
class WebContentColumn extends StatelessWidget {
  const WebContentColumn({
    super.key,
    required this.child,
    this.width = ContentWidth.wide,
    this.gutter = true,
    this.applyBelowWebTier = false,
  });

  final Widget child;
  final ContentWidth width;

  /// Add the tier's horizontal gutter inside the cap.
  final bool gutter;

  /// Also constrain on compact and medium tiers. Off by default so mobile and
  /// tablet keep whatever the screen already did.
  final bool applyBelowWebTier;

  @override
  Widget build(BuildContext context) {
    final tier = context.widthTier;
    if (!tier.isWebTier && !applyBelowWebTier) return child;

    final maxWidth = width.forTier(tier);
    Widget content = child;

    if (gutter) {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: PageGutter.forTier(tier)),
        child: content,
      );
    }

    if (!maxWidth.isFinite) return content;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

/// Surface used for grouped content on the web — the desktop equivalent of the
/// mobile card, with a border instead of a shadow so a grid of them does not
/// read as noisy.
class WebCard extends StatelessWidget {
  const WebCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.title,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
