import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'account_rows.dart';

/// "UPI ID" row on the Account screen: shows the saved ID, or "Add" when
/// there is none. Either way a tap opens Edit profile, where it's set.
class UpiIdRow extends StatelessWidget {
  const UpiIdRow({super.key, required this.upiId, this.showDivider = true});

  final String? upiId;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final value = upiId?.trim() ?? '';
    final hasValue = value.isNotEmpty;
    return AccountRow(
      icon: Icons.account_balance_wallet_outlined,
      label: AppStrings.upiId,
      value: hasValue ? value : AppStrings.addUpiId,
      valueColor: hasValue ? null : AppColors.brand,
      showDivider: showDivider,
      onTap: () => context.pushNamed('edit-profile'),
    );
  }
}
