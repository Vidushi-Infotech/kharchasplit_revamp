import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show PlatformInfo;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../headers/glass_large_title.dart' show GlassCapsuleScope;
import 'glass_surface.dart';

/// Header icon button. On iOS 26+ it's a Liquid Glass circle drawn by
/// Flutter ([GlassSurface]), so it animates with the page; elsewhere a
/// plain [IconButton].
///
/// Use it for every header action (back, search, settings, more…) so all
/// headers look the same. [sfSymbol] is the iOS name for [icon], e.g.
/// `magnifyingglass` for [Icons.search_rounded].
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.sfSymbol,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String sfSymbol;
  final VoidCallback? onPressed;
  final String tooltip;

  /// Icon color; defaults to the text color (the brand-red heart passes
  /// its own).
  final Color? color;

  /// Small count on the corner (notifications); 0 hides it.
  final int badgeCount;

  static const double size = 44;

  /// Whether headers draw glass buttons on this device (iOS 26+).
  static bool get isGlass => PlatformInfo.isIOS26OrHigher();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = color ?? AppColors.textPrimary(isDark);
    final inCapsule = isGlass && GlassCapsuleScope.of(context);
    final Widget button = inCapsule
        // Inside a shared capsule: just the icon, the capsule is the glass.
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: size,
              child: Center(child: Icon(icon, size: 21, color: fg)),
            ),
          )
        : isGlass
        ? SizedBox.square(
            dimension: size,
            child: GlassSurface(
              onTap: onPressed,
              child: Center(child: Icon(icon, size: 21, color: fg)),
            ),
          )
        : IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: fg),
          );

    final withBadge = badgeCount <= 0
        ? button
        : Badge(
            label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
            backgroundColor: AppColors.warning,
            offset: const Offset(-4, 2),
            child: button,
          );

    final labelled = Semantics(
      button: true,
      label: badgeCount > 0 ? '$tooltip, $badgeCount' : tooltip,
      excludeSemantics: true,
      child: withBadge,
    );
    return Tooltip(message: tooltip, child: labelled);
  }
}

/// Back arrow for headers: a glass `chevron.left` on iOS 26+, the platform
/// back icon elsewhere. Pops the current route unless [onPressed] is given.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  /// `AppBar.leading` for bars that rely on the implied back button: a
  /// glass back on iOS 26+ wherever the AppBar would have shown one
  /// ([implyLeading] mirrors `automaticallyImplyLeading`), else null so the
  /// AppBar keeps its own.
  static Widget? appBarLeading(
    BuildContext context, {
    bool implyLeading = true,
  }) {
    if (!GlassIconButton.isGlass || !implyLeading) return null;
    final dismissible = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return dismissible ? const GlassBackButton() : null;
  }

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.arrow_back_rounded,
      sfSymbol: 'chevron.left',
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      color: color,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Text action for headers (Save, Settle up, Done…). On iOS 26+ it's a
/// brand-tinted Liquid Glass pill ([GlassSurface]); elsewhere a
/// [TextButton] (with [icon] when given). A disabled pill still calls
/// [onBlocked] so the screen can say what's missing.
class GlassTextButton extends StatelessWidget {
  const GlassTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onBlocked,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onBlocked;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tap = enabled ? onPressed : onBlocked;
    if (GlassIconButton.isGlass) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          height: GlassIconButton.size,
          child: GlassSurface(
            circle: false,
            onTap: tap,
            tint: enabled ? AppColors.tealDark.withValues(alpha: 0.96) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? Colors.white
                        : AppColors.textSecondary(isDark),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final fg = enabled ? AppColors.tealDark : AppColors.textSecondary(isDark);
    return icon == null
        ? TextButton(
            onPressed: tap,
            style: TextButton.styleFrom(foregroundColor: fg),
            child: Text(label),
          )
        : TextButton.icon(
            onPressed: tap,
            style: TextButton.styleFrom(foregroundColor: fg),
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
  }
}

/// Space between glass header buttons (and before the screen edge). The
/// native circles touch otherwise; the Material fallbacks carry their own
/// padding, so on other platforms this takes no room.
class GlassGap extends StatelessWidget {
  const GlassGap({super.key, this.width = 6});

  final double width;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: GlassIconButton.isGlass ? width : 0);
}
