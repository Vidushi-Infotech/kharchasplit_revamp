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
    void edit() => context.pushNamed('edit-profile');
    return AccountRow(
      icon: Icons.qr_code_2_rounded,
      label: AppStrings.upiId,
      value: hasValue ? value : null,
      // No UPI ID yet: a clear "+ Add" button instead of a faint value.
      trailing: hasValue ? null : _AddPill(onTap: edit),
      showChevron: hasValue,
      showDivider: showDivider,
      onTap: edit,
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(AppStrings.addUpiId),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.brand),
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
