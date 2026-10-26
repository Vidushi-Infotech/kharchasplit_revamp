import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Header icon button. On iOS 26+ it's a native Liquid Glass circle with an
/// SF Symbol (adaptive_platform_ui); elsewhere a plain [IconButton].
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

  /// Whether headers draw native glass buttons on this device.
  static bool get isGlass => PlatformInfo.isIOS26OrHigher();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = color ?? AppColors.textPrimary(isDark);
    // While a page or sheet covers this one, swap the native view for the
    // Flutter button so the glass can't show through what's on top.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;

    final Widget button = isGlass && onTop
        ? SizedBox(
            width: size,
            height: size,
            child: AdaptiveButton.sfSymbol(
              onPressed: onPressed,
              enabled: onPressed != null,
              sfSymbol: SFSymbol(sfSymbol, size: 18, color: fg),
              style: AdaptiveButtonStyle.glass,
              size: AdaptiveButtonSize.large,
              useSmoothRectangleBorder: false,
              borderRadius: BorderRadius.circular(size / 2),
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

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: badgeCount > 0 ? '$tooltip, $badgeCount' : tooltip,
        excludeSemantics: true,
        child: withBadge,
      ),
    );
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
/// native prominent-glass pill in the brand color; elsewhere a
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
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (GlassIconButton.isGlass && onTop) {
      // A native view takes all the width it's given: size the pill to
      // its label.
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      return Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          width: text.width + 36,
          height: GlassIconButton.size,
          child: AdaptiveButton(
            onPressed: tap,
            label: label,
            style: enabled
                ? AdaptiveButtonStyle.prominentGlass
                : AdaptiveButtonStyle.glass,
            size: AdaptiveButtonSize.large,
            color: enabled ? AppColors.brand : null,
            textColor: enabled ? Colors.white : AppColors.textSecondary(isDark),
            useSmoothRectangleBorder: false,
            borderRadius: BorderRadius.circular(GlassIconButton.size / 2),
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
