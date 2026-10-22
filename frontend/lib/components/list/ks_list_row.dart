import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Flat list row used across the app (Splitwise-style): leading tile,
/// title with gray detail lines under it, a trailing block, and a hairline
/// divider. No card around it.
class KsListRow extends StatelessWidget {
  const KsListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitles = const [],
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.dense = false,
    this.semanticsLabel,
  });

  final Widget? leading;
  final String title;

  /// Gray detail lines under the title. A [Widget] is used as is; a
  /// [String] is shown in the secondary text style.
  final List<Object> subtitles;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final bool dense;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary(isDark),
      height: 1.3,
    );

    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final s in subtitles)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: s is Widget
                        ? s
                        : Text(
                            s.toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: secondary,
                          ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: AppColors.divider(isDark),
                        width: 0.6,
                      ),
                    )
                  : null,
            ),
            child: row,
          ),
        ),
      ),
    );
  }
}
