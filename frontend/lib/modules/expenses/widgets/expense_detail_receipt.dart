
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/buttons/glass_icon_button.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/system_ui.dart';
import '../../../core/utils/base64_async.dart';

/// "View receipt" row on the expense detail screen: decodes the saved
/// image once (off the main isolate) and opens it full screen, zoomable.
class ExpenseDetailReceipt extends StatefulWidget {
  const ExpenseDetailReceipt({
    super.key,
    required this.base64Data,
    required this.isDark,
  });

  final String base64Data;
  final bool isDark;

  @override
  State<ExpenseDetailReceipt> createState() => _ExpenseDetailReceiptState();
}

class _ExpenseDetailReceiptState extends State<ExpenseDetailReceipt> {
  /// Cached decoded bytes — base64-decoding a multi-MB receipt every build
  /// (which happened on every theme tick / parent rebuild) burns CPU and
  /// drops frames. Done once here, off the main isolate, refreshed only if
  /// the source string changes (rare — receipts are immutable per expense).
  Uint8List? _bytes;
  String? _decodedFor;
  bool _decoding = true;

  Future<void> _decode() async {
    final source = widget.base64Data;
    if (_decodedFor == source) return;
    _decodedFor = source;
    _decoding = true;
    final bytes = await base64DecodeAsync(source);
    // Widget may have gone away, or the source may have changed again
    // while we were decoding — drop a stale result.
    if (!mounted || _decodedFor != source) return;
    setState(() {
      _bytes = bytes;
      _decoding = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(ExpenseDetailReceipt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Data != widget.base64Data) {
      _decode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bytes = _bytes;
    final canShow = bytes != null;

    final title = canShow
        ? AppStrings.viewReceipt
        : (_decoding ? 'Loading receipt…' : 'Receipt unavailable');
    return KsListRow(
      dense: true,
      showDivider: false,
      leading: CategoryTile(
        icon: Icons.receipt_long_rounded,
        color: AppColors.tealDark,
        size: 40,
      ),
      title: title,
      subtitles: [
        if (canShow)
          'Tap to open the bill image'
        else if (!_decoding)
          "Couldn't decode the saved image",
      ],
      trailing: canShow
          ? Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(isDark),
            )
          : null,
      onTap: canShow ? () => _showFullScreen(context, bytes) : null,
    );
  }

  void _showFullScreen(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (_, _, _) => Scaffold(
          backgroundColor: Colors.transparent,
          // Over the near-black backdrop: light status bar icons.
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppSystemUi.alwaysDark(),
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5,
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GlassIconButton.isGlass
                        ? GlassIconButton(
                            icon: Icons.close_rounded,
                            sfSymbol: 'xmark',
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            color: Colors.white,
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
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
