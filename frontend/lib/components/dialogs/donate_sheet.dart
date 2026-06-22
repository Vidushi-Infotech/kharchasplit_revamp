import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/donate_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Opens the "Support KharchaSplit" bottom sheet — a UPI QR code + the UPI ID,
/// with an option to save/download the QR so it can be uploaded into a UPI app
/// to pay from the same device.
Future<void> showDonateSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _DonateSheet(),
  );
}

class _DonateSheet extends StatefulWidget {
  const _DonateSheet();

  @override
  State<_DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<_DonateSheet> {
  // Wraps the white QR card so it can be captured to a PNG for saving.
  final GlobalKey _qrKey = GlobalKey();
  bool _saving = false;

  Future<void> _copyUpi() async {
    await Clipboard.setData(const ClipboardData(text: DonateConfig.upiId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI ID copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Captures the QR card as a PNG and opens the share/save sheet so the user
  /// can store it in Photos/Files — then upload it into their UPI app to pay
  /// on this same device (you can't scan your own screen).
  Future<void> _saveQr() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('no boundary');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('encode failed');
      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kharchasplit-donate-qr.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'KharchaSplit donation QR',
          text: 'Support KharchaSplit · UPI: ${DonateConfig.upiId}',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the QR. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFE53935),
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              'Support KharchaSplit',
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'KharchaSplit is free. If it helps you, a small tip keeps it '
              'running. Thank you! 💚',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark), height: 1.35),
            ),
            const SizedBox(height: 18),

            // QR — wrapped in a RepaintBoundary so it can be saved as PNG.
            // Always on a white card so it scans in dark mode too.
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider(isDark)),
                ),
                child: QrImageView(
                  data: DonateConfig.upiUri(),
                  version: QrVersions.auto,
                  size: 208,
                  backgroundColor: Colors.white,
                  // ignore: deprecated_member_use
                  foregroundColor: const Color(0xFF111111),
                  gapless: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan with another phone, or save it to pay from this device.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 16),

            // UPI ID row with copy
            Material(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _copyUpi,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: AppColors.tealDark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UPI ID',
                              style: AppTextStyles.caption(isDark).copyWith(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              DonateConfig.upiId,
                              style: AppTextStyles.body2(
                                isDark,
                              ).copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Save / download the QR image
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _saving ? null : _saveQr,
                  child: Ink(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.tealLight, AppColors.tealDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_saving)
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
                          const Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _saving ? 'Saving…' : 'Save QR',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To pay on this phone: save the QR, open your UPI app → Scan → '
              'upload from gallery.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
