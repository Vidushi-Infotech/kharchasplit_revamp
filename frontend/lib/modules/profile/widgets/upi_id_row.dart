import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'account_rows.dart';

/// "UPI ID" row on the Account screen: shows the saved ID, or a "+ Add"
/// button when there is none. Either way a tap opens Edit profile, where
/// it's set. A "NEW" pill highlights the feature until the row is tapped
/// once or an ID is saved.
class UpiIdRow extends StatefulWidget {
  const UpiIdRow({super.key, required this.upiId, this.showDivider = true});

  final String? upiId;
  final bool showDivider;

  @override
  State<UpiIdRow> createState() => _UpiIdRowState();
}

class _UpiIdRowState extends State<UpiIdRow> {
  static const _seenKey = 'seen_new_upi_id_v1';

  /// Off until prefs say it hasn't been seen, so it never flashes.
  bool _showNew = false;

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_seenKey) ?? false;
      if (mounted && !seen) setState(() => _showNew = true);
    } catch (_) {
      // No prefs: skip the highlight rather than show it forever.
    }
  }

  Future<void> _markSeen() async {
    if (_showNew) setState(() => _showNew = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.upiId?.trim() ?? '';
    final hasValue = value.isNotEmpty;
    void edit() {
      _markSeen();
      context.pushNamed('edit-profile');
    }

    return AccountRow(
      icon: Icons.qr_code_2_rounded,
      label: AppStrings.upiId,
      isNew: _showNew && !hasValue,
      value: hasValue ? value : null,
      // No UPI ID yet: a clear "+ Add" button instead of a faint value.
      trailing: hasValue ? null : _AddPill(onTap: edit),
      showChevron: hasValue,
      showDivider: widget.showDivider,
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
