import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/invoice_scanner_service.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/base64_async.dart';
import '../../../core/utils/receipt_scan_parser.dart';
import '../state/add_expense_provider.dart';
import '../state/receipt_scan_apply.dart';
import '../state/receipt_scan_controller.dart';
import 'invoice_upload_widget.dart';
import 'receipt_scan_suggestions.dart';

/// Body of the Receipt sheet: attach a photo (as before) and — with the
/// `receiptScan` flag, on Android / iOS — read it on the device and offer
/// the total, date and merchant it found.
class ReceiptScanPanel extends ConsumerWidget {
  const ReceiptScanPanel({
    super.key,
    required this.isDark,
    required this.isEditing,
    this.onTitleScanned,
  });

  final bool isDark;

  /// Editing: the date is the saved one, never "still the default".
  final bool isEditing;

  /// Puts a scanned merchant into the screen's title field.
  final ValueChanged<String>? onTitleScanned;

  Future<void> _attach(WidgetRef ref, String imagePath, bool scan) async {
    // Attach and read in parallel; the scan never blocks the receipt.
    if (scan) ref.read(receiptScanProvider.notifier).scan(imagePath);
    final notifier = ref.read(addExpenseProvider.notifier);
    try {
      final bytes = await File(imagePath).readAsBytes();
      // Off the main isolate — a full-size receipt is a multi-MB encode
      // that would freeze the sheet.
      final encoded = await base64EncodeAsync(bytes);
      notifier.state = notifier.state.copyWith(
        invoiceImagePath: imagePath,
        receiptBase64: encoded,
      );
    } catch (_) {
      notifier.state = notifier.state.copyWith(invoiceImagePath: imagePath);
    }
  }

  void _use(
    BuildContext context,
    WidgetRef ref,
    ReceiptScanResult result,
    Set<ReceiptField> fields,
  ) {
    final notifier = ref.read(addExpenseProvider.notifier);
    notifier.state = applyReceiptScan(notifier.state, result, fields);
    if (fields.contains(ReceiptField.title) && result.merchant != null) {
      onTitleScanned?.call(result.merchant!);
    }
    ref.read(receiptScanProvider.notifier).dismiss();
    HapticService.instance.success();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanOn =
        watchFeature(ref, 'receiptScan') && InvoiceScannerService.isSupported;
    final scan = ref.watch(receiptScanProvider);
    final form = ref.watch(addExpenseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InvoiceUploadWidget(
          initialImagePath: form.invoiceImagePath,
          onImageSelected: (path, _) => _attach(ref, path, scanOn),
          onRemoved: () {
            ref.read(receiptScanProvider.notifier).dismiss();
            final notifier = ref.read(addExpenseProvider.notifier);
            notifier.state = notifier.state.copyWith(clearReceipt: true);
          },
        ),
        if (scanOn) ...[
          const SizedBox(height: 12),
          _scanStatus(context, ref, scan, form),
        ],
      ],
    );
  }

  Widget _scanStatus(
    BuildContext context,
    WidgetRef ref,
    ReceiptScanState scan,
    AddExpenseState form,
  ) {
    switch (scan.status) {
      case ReceiptScanStatus.idle:
        return const SizedBox.shrink();
      case ReceiptScanStatus.scanning:
        return Semantics(
          liveRegion: true,
          label: AppStrings.receiptScanning,
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(width: 10),
              Text(AppStrings.receiptScanning, style: _note),
            ],
          ),
        );
      case ReceiptScanStatus.failed:
        return _muted(AppStrings.receiptUnreadable);
      case ReceiptScanStatus.done:
        final result = scan.result!;
        final now = DateTime.now();
        final suggestions = receiptSuggestions(
          form,
          result,
          dateIsDefault: !isEditing && DateUtils.isSameDay(form.date, now),
        );
        if (suggestions.isEmpty) {
          // Nothing new to offer; say so only when the total is missing.
          return result.total == null
              ? _muted(AppStrings.receiptNoTotal)
              : const SizedBox.shrink();
        }
        return ReceiptScanSuggestionsCard(
          isDark: isDark,
          form: form,
          result: result,
          suggestions: suggestions,
          onUse: (fields) => _use(context, ref, result, fields),
          onDismiss: () => ref.read(receiptScanProvider.notifier).dismiss(),
        );
    }
  }

  TextStyle get _note => AppTextStyles.body2(
    isDark,
  ).copyWith(color: AppColors.textSecondary(isDark));

  Widget _muted(String text) => Semantics(
    liveRegion: true,
    child: Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppColors.textSecondary(isDark),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: _note)),
      ],
    ),
  );
}
