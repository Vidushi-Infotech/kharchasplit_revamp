import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'add_expense_sheet_header.dart';

/// "Enter rate" sheet, offered when no exchange rate could be looked up
/// (503 FX_UNAVAILABLE): 1 [from] in [to]. Resolves to the rate, or null
/// on dismiss. The form sends it as `fxRate`.
Future<double?> showFxRateSheet(
  BuildContext context, {
  required bool isDark,
  required String from,
  required String to,
  double? initial,
}) {
  return showAdaptiveSheet<double>(
    context: context,
    size: AdaptiveSheetSize.small,
    // Above the floating tab bar.
    useRootNavigator: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) =>
        _FxRateBody(isDark: isDark, from: from, to: to, initial: initial),
  );
}

class _FxRateBody extends StatefulWidget {
  const _FxRateBody({
    required this.isDark,
    required this.from,
    required this.to,
    this.initial,
  });

  final bool isDark;
  final String from;
  final String to;
  final double? initial;

  @override
  State<_FxRateBody> createState() => _FxRateBodyState();
}

class _FxRateBodyState extends State<_FxRateBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial}',
  );

  double? get _rate {
    final v = double.tryParse(_controller.text.trim());
    return v != null && v > 0 && v < 1000000 ? v : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AddExpenseSheetHandle(isDark: isDark)),
              AddExpenseSheetTitle(
                text: AppStrings.fxRateQuestion(widget.from, widget.to),
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,6}'),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixText: '1 ${widget.from} = ',
                        suffixText: widget.to,
                        filled: true,
                        fillColor: AppColors.cardBg(isDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.fxRateHint,
                      style: AppTextStyles.caption(
                        isDark,
                      ).copyWith(color: AppColors.textSecondary(isDark)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.tealDark,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _rate == null
                          ? null
                          : () => Navigator.of(context).pop(_rate),
                      child: const Text(AppStrings.fxUseRate),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
