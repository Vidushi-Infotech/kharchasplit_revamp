import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show PlatformInfo;
import 'package:flutter/material.dart';

import '../../components/buttons/glass_surface.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';

/// iOS 26+ gets the Liquid Glass tab bar and buttons (see mode_tab_bar.dart);
/// Android and older iOS keep the Material ones.
bool get useGlassShell => PlatformInfo.isIOS26OrHigher();

/// "Add expense" as a brand-tinted Liquid Glass pill floating above the
/// glass tab bar. Drawn by Flutter (like the header buttons), so it is
/// there immediately and moves with the page.
class GlassAddExpenseButton extends StatelessWidget {
  const GlassAddExpenseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.addExpense,
      excludeSemantics: true,
      child: SizedBox(
        height: 52,
        child: GlassSurface(
          circle: false,
          radius: 26,
          tint: AppColors.tealDark.withValues(alpha: 0.96),
          onTap: () {
            HapticService.instance.tap();
            onPressed();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  AppStrings.addExpense,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
