import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// The one place that decides how a balance looks: green when money comes
/// back to you, orange when you owe, gray when settled or not involved.
/// Rows pick a tone from the amount and never choose colors by hand, so
/// the label and the amount can't disagree.
enum BalanceTone {
  owed,
  owe,
  settled,
  notInvolved;

  /// Positive = you get money back, negative = you owe. Amounts under half
  /// a paisa count as settled.
  static BalanceTone fromAmount(double amount) {
    if (amount > 0.004) return BalanceTone.owed;
    if (amount < -0.004) return BalanceTone.owe;
    return BalanceTone.settled;
  }

  Color color(bool isDark) => switch (this) {
        BalanceTone.owed => AppColors.owed,
        BalanceTone.owe => AppColors.owe,
        BalanceTone.settled ||
        BalanceTone.notInvolved =>
          isDark ? AppColors.darkTextSecondary : AppColors.settled,
      };

  /// Label above the amount on a group or friend row.
  String get balanceLabel => switch (this) {
        BalanceTone.owed => AppStrings.youAreOwedLower,
        BalanceTone.owe => AppStrings.youOweLower,
        BalanceTone.settled => AppStrings.settledUpLower,
        BalanceTone.notInvolved => AppStrings.notInvolved,
      };

  /// Label above the amount on an expense row.
  String get expenseLabel => switch (this) {
        BalanceTone.owed => AppStrings.youLent,
        BalanceTone.owe => AppStrings.youBorrowed,
        BalanceTone.settled ||
        BalanceTone.notInvolved =>
          AppStrings.notInvolved,
      };
}
