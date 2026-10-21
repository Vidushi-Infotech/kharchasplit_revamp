import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

/// One person's share on the expense detail "Split among" card, with an
/// optional Settle up / Remind chip.
class ExpenseDetailSplitRow extends StatelessWidget {
  const ExpenseDetailSplitRow({
    super.key,
    required this.split,
    required this.currency,
    required this.isDark,
    required this.splitType,
    required this.totalAmount,
    required this.totalShares,
    required this.showWorking,
    this.fallbackMember,
    this.displayName,
    this.isSelf = false,
    this.actionLabel,
    this.actionIcon,
    this.actionColor,
    this.onAction,
  });

  final SplitModel split;
  final String currency;
  final bool isDark;
  final SplitType splitType;
  final double totalAmount;
  final double totalShares;
  final bool showWorking;

  /// Optional Settle Up / Remind action for this row (null = no button).
  final String? actionLabel;
  final IconData? actionIcon;
  final Color? actionColor;
  final VoidCallback? onAction;

  /// Group member resolved from the split's userId — used when the split's
  /// own avatar is blank so the row still shows the member's photo.
  final UserModel? fallbackMember;

  /// Pre-resolved display name (real name → device contact → phone). When
  /// null, falls back to the split/member name locally.
  final String? displayName;
  final bool isSelf;

  /// Name to show: the pre-resolved [displayName], else the split's own
  /// userName, else the group member's name, else a safe placeholder.
  String get _displayName {
    final resolved = displayName?.trim() ?? '';
    if (resolved.isNotEmpty) return resolved;
    if (split.userName.trim().isNotEmpty) return split.userName;
    final memberName = fallbackMember?.name.trim() ?? '';
    return memberName.isNotEmpty ? memberName : 'Unknown member';
  }

  /// Avatar URL to show: the split's own, else the resolved member's.
  String? get _displayAvatarUrl {
    final own = split.userAvatarUrl;
    if (own != null && own.isNotEmpty) return own;
    return fallbackMember?.avatarUrl;
  }

  String _amount(double v) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: currency,
    decimalDigits: 0,
  ).format(v);

  /// Resolve percentage to display: prefer the value stored at create time,
  /// otherwise derive it from the resolved amount (works for legacy rows
  /// where the DB column is NULL).
  double? _resolvedPercentage() {
    if (split.percentage > 0) return split.percentage;
    if (totalAmount > 0 && split.owedShare >= 0) {
      return split.owedShare / totalAmount * 100;
    }
    return null;
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String? _inputChip() {
    switch (splitType) {
      case SplitType.percentage:
        final p = _resolvedPercentage();
        if (p == null) return null;
        return '${_trim(p)}%';
      case SplitType.shares:
        if (split.shares <= 0) return null;
        return '${_trim(split.shares)} ${split.shares == 1 ? 'share' : 'shares'}';
      case SplitType.equal:
      case SplitType.exact:
        return null;
    }
  }

  String? _workingLine() {
    switch (splitType) {
      case SplitType.percentage:
        final p = _resolvedPercentage();
        if (p == null) return null;
        return '${_trim(p)}%  ×  ${_amount(totalAmount)}  =  ${_amount(split.owedShare)}';
      case SplitType.shares:
        if (split.shares <= 0 || totalShares <= 0) return null;
        return '${_trim(split.shares)} / ${_trim(totalShares)}  ×  ${_amount(totalAmount)}  =  ${_amount(split.owedShare)}';
      case SplitType.equal:
      case SplitType.exact:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _amount(split.owedShare);
    final chip = _inputChip();
    final working = showWorking ? _workingLine() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AvatarWidget(
              name: _displayName,
              imageUrl: _displayAvatarUrl,
              radius: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelf ? '$_displayName (Me)' : _displayName,
                  style: AppTextStyles.body1(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (working != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    working,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatted,
                style: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              if (chip != null) ...[
                const SizedBox(height: 2),
                Text(
                  chip,
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 6),
                Material(
                  color: (actionColor ?? AppColors.brand).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            actionIcon,
                            size: 13,
                            color: actionColor ?? AppColors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            actionLabel!,
                            style: TextStyle(
                              color: actionColor ?? AppColors.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
