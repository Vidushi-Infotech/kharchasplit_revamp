import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/inputs/app_text_field.dart';

/// Referral code field with animated expand/collapse
class ReferralCodeField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onCodeEntered;

  const ReferralCodeField({
    Key? key,
    required this.controller,
    this.onCodeEntered,
  }) : super(key: key);

  @override
  State<ReferralCodeField> createState() => _ReferralCodeFieldState();
}

class _ReferralCodeFieldState extends State<ReferralCodeField>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Collapsed state - tappable row
        if (!_isExpanded)
          GestureDetector(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.tealDark,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Have a referral code?',
                        style: AppTextStyles.body2(isDark).copyWith(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '+',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.tealDark,
                        ),
                  ),
                ],
              ),
            ),
          ),
        // Expanded state
        if (_isExpanded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: _toggleExpand,
                    child: Text(
                      '−',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.tealDark,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Input field
                AppTextField(
                  label: 'Referral Code',
                  hint: 'Enter code (e.g., FRIEND50)',
                  controller: widget.controller,
                  prefixIcon: Icons.card_giftcard_rounded,
                ),
                const SizedBox(height: 8),
                // Helper text
                Text(
                  '✓ You and your friend both get ₹50 credit',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.greenLight,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
