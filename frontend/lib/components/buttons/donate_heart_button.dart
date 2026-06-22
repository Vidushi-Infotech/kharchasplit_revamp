import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../dialogs/donate_sheet.dart';

/// Small circular heart button for app headers — opens the donate (UPI QR)
/// sheet. Styled to match the other circular header icons (back, notifications).
class DonateHeartButton extends StatelessWidget {
  const DonateHeartButton({
    super.key,
    this.size = 40,
    this.iconSize = 18,
    this.cornerRadius,
  });

  final double size;
  final double iconSize;

  /// When null the button is a circle (matches circular back buttons); set a
  /// value to render a rounded square (matches the dashboard's icon buttons).
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCircle = cornerRadius == null;
    final shape = isCircle
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius!),
          );
    return Semantics(
      button: true,
      label: 'Support KharchaSplit',
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDonateSheet(context),
          customBorder: shape,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle
                  ? null
                  : BorderRadius.circular(cornerRadius!),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: iconSize,
              color: const Color(0xFFE53935), // red
            ),
          ),
        ),
      ),
    );
  }
}
