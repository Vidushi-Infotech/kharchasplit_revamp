import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/invoice_scanner_service.dart';
import '../../../core/utils/receipt_scan_parser.dart';

enum ReceiptScanStatus { idle, scanning, done, failed }

class ReceiptScanState {
  const ReceiptScanState(this.status, [this.result]);
  final ReceiptScanStatus status;

  /// Set when [status] is done (may still be empty — nothing readable).
  final ReceiptScanResult? result;
}

/// The receipt sheet's scan (`receiptScan` flag): runs on-device OCR on
/// the photo just attached and holds what it found until the user uses or
/// dismisses it. autoDispose: closing the sheet forgets it.
class ReceiptScanController extends Notifier<ReceiptScanState> {
  /// Bumped per scan, so a slow scan of a replaced photo is ignored.
  int _run = 0;

  @override
  ReceiptScanState build() => const ReceiptScanState(ReceiptScanStatus.idle);

  Future<void> scan(String imagePath) async {
    final run = ++_run;
    state = const ReceiptScanState(ReceiptScanStatus.scanning);
    final result = await InvoiceScannerService.scan(imagePath);
    if (!ref.mounted || run != _run) return;
    state = result == null
        ? const ReceiptScanState(ReceiptScanStatus.failed)
        : ReceiptScanState(ReceiptScanStatus.done, result);
  }

  void dismiss() {
    _run++;
    state = const ReceiptScanState(ReceiptScanStatus.idle);
  }
}

final receiptScanProvider =
    NotifierProvider.autoDispose<ReceiptScanController, ReceiptScanState>(
      ReceiptScanController.new,
    );
