import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/category_model.dart';
import '../../../../models/personal_bill_model.dart';
import 'bill_style.dart';

/// One bill: its category icon, name, when it's due, the amount and a Pay
/// button. Tap the row to edit it.
class BillRow extends StatelessWidget {
  const BillRow({
    super.key,
    required this.bill,
    required this.onTap,
    required this.onPay,
  });

  final PersonalBill bill;
  final VoidCallback onTap;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = CategoryModel.fromId(bill.category)!;
    final dueColor = billDueColor(bill, isDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(cat.icon, size: 19, color: cat.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${billDueText(bill)} · ${bill.frequency.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: dueColor,
                      fontSize: 12,
                      fontWeight: bill.status == BillStatus.upcoming
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyFormatter.format(bill.amount, currency: '₹'),
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onPay,
              style: FilledButton.styleFrom(
                backgroundColor: bill.status == BillStatus.upcoming
                    ? AppColors.brand.withValues(alpha: 0.18)
                    : AppColors.brand,
                foregroundColor: bill.status == BillStatus.upcoming
                    ? AppColors.brand
                    : Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
              ),
              child: const Text(AppStrings.billPay),
            ),
          ],
        ),
      ),
    );
  }
}
