import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../components/buttons/primary_button.dart';
import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shown when no UPI app took the `upi://pay` link (none installed) and on
/// web/desktop: the payee's UPI ID to copy plus a QR of the same link to
/// scan from a phone. Resolves true when the user taps "I've paid", so the
/// caller can ask the usual "Did it go through?" question.
Future<bool> showUpiFallbackSheet(
  BuildContext context, {
  required String payeeVpa,
  required String payeeName,
  required String amountLabel,
  required String upiUri,
  required bool launchFailed,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showAdaptiveSheet<bool>(
    context: context,
    size: AdaptiveSheetSize.small,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UpiFallbackSheet(
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      amountLabel: amountLabel,
      upiUri: upiUri,
      launchFailed: launchFailed,
    ),
  );
  return result ?? false;
}

class _UpiFallbackSheet extends StatelessWidget {
  const _UpiFallbackSheet({
    required this.payeeVpa,
    required this.payeeName,
    required this.amountLabel,
    required this.upiUri,
    required this.launchFailed,
  });

  final String payeeVpa;
  final String payeeName;
  final String amountLabel;
  final String upiUri;
  final bool launchFailed;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: payeeVpa));
    messenger.showSnackBar(
      const SnackBar(
        content: Text(AppStrings.upiIdCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark), height: 1.35);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              AppStrings.payNameByUpi(payeeName),
              textAlign: TextAlign.center,
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              amountLabel,
              style: AppTextStyles.headline2(
                isDark,
              ).copyWith(color: AppColors.brand),
            ),
            if (launchFailed) ...[
              const SizedBox(height: 6),
              Text(
                AppStrings.noUpiAppFound,
                textAlign: TextAlign.center,
                style: muted,
              ),
            ],
            const SizedBox(height: 16),
            // Always on a white card so it scans in dark mode too.
            Semantics(
              label: AppStrings.scanWithUpiApp,
              image: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider(isDark)),
                ),
                child: QrImageView(
                  data: upiUri,
                  version: QrVersions.auto,
                  size: 196,
                  backgroundColor: Colors.white,
                  gapless: true,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(AppStrings.scanWithUpiApp, style: muted),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider(isDark)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      payeeVpa,
                      maxLines: 1,
                      style: AppTextStyles.body2(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(AppStrings.copyUpiId),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: AppStrings.iHavePaid,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
