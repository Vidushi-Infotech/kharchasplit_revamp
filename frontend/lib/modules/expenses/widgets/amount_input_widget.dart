import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  /// save — render the underline and helper text in red.
  final bool hasError;

  const AmountInputWidget({
    Key? key,
    required this.amount,
    required this.currency,
    required this.onChanged,
    this.autoFocus = false,
    this.hasError = false,
  }) : super(key: key);

  @override
  State<AmountInputWidget> createState() => _AmountInputWidgetState();
}

class _AmountInputWidgetState extends State<AmountInputWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.amount > 0 ? widget.amount.toInt().toString() : '',
    );
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
    // Update controller if amount changed externally (e.g., from invoice scan)
    if (oldWidget.amount != widget.amount && widget.amount > 0) {
      _controller.text = widget.amount.toInt().toString();
      // Position cursor at end of text to prevent auto-selection
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              widget.currency,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: widget.autoFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary(isDark),
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.inputBorder(isDark),
                      width: 2,
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: enabledBorderColor,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: focusedBorderColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  widget.onChanged(amount);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.hasError
              ? 'Enter an amount greater than 0'
              : 'Tap to enter amount',
          style: AppTextStyles.caption(isDark).copyWith(
            color: widget.hasError
                ? errorColor
                : AppColors.textSecondary(isDark),
            fontSize: 11,
            fontWeight: widget.hasError ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
