import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/invoice_scanner_service.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../state/add_expense_provider.dart';
import 'add_expense_extras_summary.dart';

/// Highlighted "Scan a receipt" card at the top of a new, still empty
/// expense — the quickest way in, so it's shown up front (and above the
/// keyboard) instead of hiding behind the camera icon. Gone once there's an amount or a receipt, and when editing.
class ScanReceiptPrompt extends ConsumerWidget {
  const ScanReceiptPrompt({
    super.key,
    required this.isEditing,
    required this.onTap,
  });

  final bool isEditing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(addExpenseProvider);
    if (isEditing ||
        form.amount > 0 ||
        AddExpenseExtrasSummary.hasReceiptIn(form)) {
      return const SizedBox.shrink();
    }
    final canScan =
        watchFeature(ref, 'receiptScan') && InvoiceScannerService.isSupported;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final title = canScan
        ? AppStrings.scanReceiptTitle
        : AppStrings.addReceiptTitle;
    final subtitle = canScan
        ? AppStrings.scanReceiptHint
        : AppStrings.addReceiptHint;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        excludeSemantics: true,
        child: Material(
          color: AppColors.brand.withValues(alpha: isDark ? 0.18 : 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.brand.withValues(alpha: isDark ? 0.5 : 0.35),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      canScan
                          ? Icons.document_scanner_outlined
                          : Icons.photo_camera_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary(isDark),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
