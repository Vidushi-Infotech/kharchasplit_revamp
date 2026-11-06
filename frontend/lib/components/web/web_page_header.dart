import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'hoverable.dart';

/// A single step in a [WebPageHeader] breadcrumb trail.
class Crumb {
  const Crumb(this.label, [this.location]);

  final String label;

  /// Null for the current page, which is not a link.
  final String? location;
}

/// Page title block for the web shell.
///
/// Replaces the mobile [AppBar] on desktop, where a centered 56px title bar
/// wastes the top of a 900px-tall window and puts actions far from the content
/// they act on. Actions sit on the title's baseline instead, and an optional
/// breadcrumb trail restores the sense of place that the mobile back button
/// provides.
class WebPageHeader extends StatelessWidget {
  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.breadcrumbs = const [],
    this.onBack,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Trail from the section root to this page. The last entry should have a
  /// null location.
  final List<Crumb> breadcrumbs;

  /// Shown as a back affordance beside the title. Supply for detail pages that
  /// were pushed rather than navigated to.
  final VoidCallback? onBack;

  /// Tabs, filters or a search bar pinned under the title.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breadcrumbs.isNotEmpty) ...[
          _Breadcrumbs(crumbs: breadcrumbs, isDark: isDark),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                  onPressed: onBack,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ),
          ],
        ),
        if (bottom != null) ...[const SizedBox(height: 20), bottom!],
      ],
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.crumbs, required this.isDark});

  final List<Crumb> crumbs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark));

    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final crumb = crumbs[i];
      final isLast = i == crumbs.length - 1;

      children.add(
        crumb.location == null
            ? Text(
                crumb.label,
                style: style?.copyWith(
                  color: AppColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              )
            : HoverableRow(
                borderRadius: 5,
                onTap: () => context.go(crumb.location!),
                semanticLabel: 'Go to ${crumb.label}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(crumb.label, style: style),
                ),
              ),
      );

      if (!isLast) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
