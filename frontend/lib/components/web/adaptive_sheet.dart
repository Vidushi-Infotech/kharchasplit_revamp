import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';

/// Size classes for the desktop dialog form of a sheet.
enum AdaptiveSheetSize {
  /// Confirmations and short pickers.
  small(width: 420, maxHeightFactor: 0.7),

  /// Forms with a handful of fields.
  medium(width: 560, maxHeightFactor: 0.8),

  /// Long pickers and multi-section forms — contacts, wallet setup.
  large(width: 720, maxHeightFactor: 0.86);

  const AdaptiveSheetSize({required this.width, required this.maxHeightFactor});

  final double width;
  final double maxHeightFactor;
}

/// Presents a panel as a modal bottom sheet on touch layouts and as a centered
/// dialog on the web shell.
///
/// A bottom sheet sliding up full-width from the bottom edge of a 1440px
/// window reads as broken; the same content in a centered dialog reads as
/// intentional. Below [Breakpoints.shellWeb] this forwards to
/// [showModalBottomSheet] with the same arguments the call sites already use,
/// so touch behaviour is unchanged.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  AdaptiveSheetSize size = AdaptiveSheetSize.medium,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  final isWeb = context.widthTier.isWebTier;

  if (!isWeb) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      backgroundColor: backgroundColor,
      shape: shape,
    );
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) {
      final media = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        backgroundColor: backgroundColor ?? AppColors.surface(isDark),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        shape:
            shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width,
            maxHeight: media.height * size.maxHeightFactor,
          ),
          // Sheet bodies are written expecting to sit above the keyboard and
          // the home indicator. Zeroing the view insets inside the dialog
          // stops that padding from opening a gap on desktop.
          child: MediaQuery.removeViewInsets(
            context: dialogContext,
            removeBottom: true,
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}

/// Header row for an adaptive sheet: a drag handle on touch, a title bar with
/// a close button on the web.
class AdaptiveSheetHeader extends StatelessWidget {
  const AdaptiveSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (!context.widthTier.isWebTier) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
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
          ?trailing,
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
