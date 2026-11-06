import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/receipt_scan_parser.dart';
import '../utils/receipt_scan_rows.dart';

/// Reads a receipt photo on the device: Google ML Kit text recognition
/// (Latin script, bundled model — no network, nothing leaves the phone),
/// then [parseReceiptText] for the total, date and merchant.
///
/// Android and iOS only ([isSupported]); ML Kit runs off the UI thread on
/// its own. Photos come from the receipt picker already downscaled to
/// 1600 px wide, which is plenty for printed bills.
class InvoiceScannerService {
  InvoiceScannerService._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// The parsed receipt, or null when the photo couldn't be read at all.
  /// [now] caps the date (never in the future).
  static Future<ReceiptScanResult?> scan(
    String imagePath, {
    DateTime? now,
  }) async {
    if (!isSupported) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final lines = [
        for (final block in recognized.blocks)
          for (final line in block.lines)
            ReceiptOcrLine(
              line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              bottom: line.boundingBox.bottom,
            ),
      ];
      if (lines.isEmpty) return const ReceiptScanResult();
      return parseReceiptText(receiptRowsText(lines), now: now);
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
