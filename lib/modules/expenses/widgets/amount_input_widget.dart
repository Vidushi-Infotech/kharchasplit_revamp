import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../components/text/currency_text.dart';

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
      text: widget.amount > 0 ? widget.amount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          // Display amount
          if (widget.amount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CurrencyText(
                widget.amount,
                currency: widget.currency,
                textStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                animated: true,
              ),
            ),
          // Input field
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.headline3(isDark),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: AppTextStyles.headline3(isDark)
                  .copyWith(color: AppColors.textSecondary(isDark)),
              prefixText: '${widget.currency} ',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              final amount = double.tryParse(value) ?? 0;
              widget.onChanged(amount);
            },
          ),
        ],
      ),
    );
  }
}
