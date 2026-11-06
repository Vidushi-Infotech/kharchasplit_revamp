import 'package:flutter/material.dart';

import '../menus/glass_menu.dart';
import 'glass_icon_button.dart';

/// Header ⋮ menu (or any pull-down menu). On iOS 26+ it opens the iOS 26
/// style glass menu ([showGlassMenu]) with [glassItems], growing out of a
/// Liquid Glass circle (or the plain icon with [plainTrigger]); elsewhere
/// [menu] itself is shown, unchanged.
class GlassMenuButton<T> extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.menu,
    this.icon = Icons.more_vert_rounded,
    this.sfSymbol = 'ellipsis',
    this.color,
    this.glassItems,
    this.plainTrigger = false,
  });

  /// The menu as it looks off iOS 26; its items and callbacks are reused.
  final PopupMenuButton<T> menu;
  final IconData icon;
  final String sfSymbol;

  /// Symbol color on glass (white over a banner).
  final Color? color;

  /// The rows of the iOS 26 menu; [menu.onSelected] gets the picked value.
  /// Null falls back to [menu]'s own items in a Material popup.
  final List<GlassMenuItem<T>>? glassItems;

  /// On iOS 26, keep [menu]'s own icon as the trigger instead of a glass
  /// circle (for menus inside a page, not in a header).
  final bool plainTrigger;

  @override
  Widget build(BuildContext context) {
    if (!GlassIconButton.isGlass) return menu;
    if (plainTrigger) {
      return Builder(
        builder: (buttonContext) => IconButton(
          tooltip:
              menu.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
          icon: menu.icon ?? Icon(icon),
          onPressed: menu.enabled ? () => _open(buttonContext) : null,
        ),
      );
    }
    return Builder(
      builder: (buttonContext) => GlassIconButton(
        icon: icon,
        sfSymbol: sfSymbol,
        tooltip:
            menu.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        color: color,
        onPressed: menu.enabled ? () => _open(buttonContext) : null,
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final glass = glassItems;
    if (glass != null) {
      if (glass.isEmpty) return;
      menu.onOpened?.call();
      final value = await showGlassMenu<T>(context, glass);
      if (!context.mounted) return;
      if (value == null) {
        menu.onCanceled?.call();
      } else {
        menu.onSelected?.call(value);
      }
      return;
    }
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    // Drop the menu just under the circle, like iOS context menus.
    final below = Offset(0, button.size.height + 4) + menu.offset;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(below, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + below,
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final items = menu.itemBuilder(context);
    if (items.isEmpty) return;
    menu.onOpened?.call();
    final value = await showMenu<T>(
      context: context,
      position: position,
      items: items,
      initialValue: menu.initialValue,
      color: menu.color,
      shape: menu.shape,
      elevation: menu.elevation,
      constraints: menu.constraints,
    );
    if (!context.mounted) return;
    if (value == null) {
      menu.onCanceled?.call();
    } else {
      menu.onSelected?.call(value);
    }
  }
}
