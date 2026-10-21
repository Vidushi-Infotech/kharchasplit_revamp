import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Sticky gradient Save bar pinned under the Add/Edit expense form.
class AddExpenseSaveBar extends StatelessWidget {
  const AddExpenseSaveBar({
    super.key,
    required this.isDark,
    required this.enabled,
    required this.loading,
    required this.horizontalPad,
    required this.maxFormWidth,
    required this.label,
    required this.onTap,
    this.disabledHint,
    this.onDisabledTap,
  });

  final bool isDark;
  final bool enabled;
  final bool loading;
  final double horizontalPad;
  final double maxFormWidth;
  final String label;
  final String? disabledHint;
  final VoidCallback onTap;

  /// Called when the user taps the bar while it's disabled (not loading) —
  /// used to surface validation errors rather than silently ignoring the tap.
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.divider(isDark).withValues(alpha: 0.7),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxFormWidth),
              child: Semantics(
                button: true,
                enabled: enabled,
                label: label,
                child: Opacity(
                  opacity: (enabled || loading) ? 1 : 0.6,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: enabled ? onTap : (loading ? null : onDisabledTap),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.tealLight, AppColors.tealDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: (enabled || loading)
                              ? [
                                  BoxShadow(
                                    color: AppColors.tealDark.withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (loading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                enabled
                                    ? Icons.check_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                loading
                                    ? 'Saving…'
                                    : (enabled
                                          ? label
                                          : (disabledHint ?? label)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body1(isDark).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
