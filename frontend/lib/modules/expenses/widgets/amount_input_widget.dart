import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AmountInputWidget extends StatefulWidget {
  final double amount;
  final String currency;
  final Function(double) onChanged;

  /// When true, the input claims focus and pops the keyboard on first
  /// build. Use for fresh "Add expense" so the user can type immediately;
  /// leave false for edit mode where the form is already populated.
  final bool autoFocus;

  /// When true, the amount is invalid (e.g. zero) and the user has tried to
  /// save — render the underline and the hint under it in red.
  final bool hasError;

  /// Opens the currency picker (`currencyConversion`); null = the symbol
  /// is just a label.
  final VoidCallback? onCurrencyTap;

  /// Spoken for the currency button, e.g. "Currency USD. Tap to change".
  final String? currencyTapLabel;

  const AmountInputWidget({
    Key? key,
    required this.amount,
    required this.currency,
    required this.onChanged,
    this.autoFocus = false,
    this.hasError = false,
    this.onCurrencyTap,
    this.currencyTapLabel,
  }) : super(key: key);

  @override
  State<AmountInputWidget> createState() => _AmountInputWidgetState();
}

class _AmountInputWidgetState extends State<AmountInputWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _text(widget.amount));
    // No controller listener: previously we did `setState({})` on every
    // keystroke just to flip `showCursor`. That fired a rebuild of this
    // widget AND the parent (via onChanged → provider write), so each char
    // triggered two full passes of the 1300-line add-expense tree. Cursor
    // is always-on now; the per-keystroke rebuild is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  @override
  void didUpdateWidget(AmountInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if amount changed externally (e.g. from a receipt
    // scan) — not when it is just what the user is typing ("12." is 12).
    final typed = double.tryParse(_controller.text) ?? 0;
    if (oldWidget.amount != widget.amount &&
        widget.amount > 0 &&
        (typed * 100).round() != (widget.amount * 100).round()) {
      _controller.text = _text(widget.amount);
      // Position cursor at end of text to prevent auto-selection
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  /// "1234" for whole amounts, "1234.50" otherwise; "" for 0.
  static String _text(double amount) {
    if (amount <= 0) return '';
    final paise = (amount * 100).round();
    return paise % 100 == 0
        ? (paise ~/ 100).toString()
        : (paise / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorColor = AppColors.errorText(isDark);
    final enabledBorderColor = widget.hasError
        ? errorColor
        : AppColors.inputBorder(isDark);
    final focusedBorderColor = widget.hasError ? errorColor : AppColors.brand;
    final big = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary(isDark),
      letterSpacing: -0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _currencyButton(isDark),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: widget.autoFocus,
                // Paise allowed (₹1,234.50 from a receipt, \$12.99).
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: big,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: big.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                  isDense: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: enabledBorderColor,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: focusedBorderColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.only(bottom: 4),
                ),
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  widget.onChanged(amount);
                },
              ),
            ),
          ],
        ),
        if (widget.hasError)
          Padding(
            padding: const EdgeInsets.only(left: 58, top: 4),
            child: Text(
              AppStrings.amountMustBePositive,
              style: AppTextStyles.caption(isDark).copyWith(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Square currency button left of the amount (Splitwise style). Opens
  /// the currency picker when [AmountInputWidget.onCurrencyTap] is set.
  Widget _currencyButton(bool isDark) {
    final onTap = widget.onCurrencyTap;
    final box = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Text(
        widget.currency,
        maxLines: 1,
        style: TextStyle(
          fontSize: widget.currency.length > 2 ? 13 : 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(isDark),
        ),
      ),
    );
    if (onTap == null) return box;
    return Semantics(
      button: true,
      label: widget.currencyTapLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: box,
        ),
      ),
    );
  }
}
