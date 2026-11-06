import '../../../core/constants/app_strings.dart';

/// The Record a payment button: "Settle up" when the amount pays off all
/// you owe this person in the group, "Record" for a part payment (or when
/// we don't know the balance). [owed] > 0 = what you owe them.
String settleButtonLabel({required double? owed, required double? amount}) {
  if (owed == null || owed <= 0.004 || amount == null) {
    return AppStrings.recordLabel;
  }
  return amount >= owed - 0.004 ? AppStrings.settleUp : AppStrings.recordLabel;
}
