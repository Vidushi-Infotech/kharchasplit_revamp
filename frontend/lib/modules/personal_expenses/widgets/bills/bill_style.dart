import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/personal_bill_model.dart';

extension BillFrequencyLabel on BillFrequency {
  String get label => switch (this) {
    BillFrequency.weekly => AppStrings.billWeekly,
    BillFrequency.biweekly => AppStrings.billBiweekly,
    BillFrequency.monthly => AppStrings.billMonthly,
    BillFrequency.yearly => AppStrings.billYearly,
  };
}

/// "Due today", "Due tomorrow", "Due in 3 days", "Due 12 Nov",
/// "Overdue by 2 days".
String billDueText(PersonalBill b) {
  final d = b.daysLeft;
  if (d < 0) return AppStrings.billOverdueBy(-d);
  if (d == 0) return AppStrings.billDueToday;
  if (d == 1) return AppStrings.billDueTomorrow;
  if (d <= 7) return AppStrings.billDueIn(d);
  return AppStrings.billDueOn(DateFormat('d MMM').format(b.nextDue));
}

/// Red when overdue, orange when due soon, quiet otherwise.
Color billDueColor(PersonalBill b, bool isDark) => switch (b.status) {
  BillStatus.overdue => AppColors.errorText(isDark),
  BillStatus.due => AppColors.warning,
  BillStatus.upcoming => AppColors.textSecondary(isDark),
};
