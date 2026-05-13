import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AmountInputWidget extends StatefulWidget {
  final double amount;
  final String currency;
  final Function(double) onChanged;

  const AmountInputWidget({
    Key? key,
    required this.amount,
    required this.currency,
    required this.onChanged,
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
    _controller.addListener(_handleTextChanged);
    // Position cursor at end of text to prevent auto-selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
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
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                showCursor: _controller.text.isNotEmpty,
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
                      color: AppColors.inputBorder(isDark),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.brand,
                      width: 2,
                    ),
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
          'Tap to enter amount',
          style: AppTextStyles.caption(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
