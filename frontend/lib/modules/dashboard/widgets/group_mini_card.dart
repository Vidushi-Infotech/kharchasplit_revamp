import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../../groups/widgets/group_cover_thumb.dart';

/// Compact horizontally-scrolling card for the Groups carousel.
class GroupMiniCard extends StatelessWidget {
  const GroupMiniCard({
    super.key,
    required this.group,
    this.onTap,
    this.width = 156,
  });

  final GroupModel group;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _statusFor(group.myBalance);

    return Semantics(
      button: true,
      label: _semanticLabel(status),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: width,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider(isDark)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.divider(isDark).withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EmojiBadge(group: group, isDark: isDark),
                  const SizedBox(height: 10),
                  Text(
                    group.name,
                    style: AppTextStyles.body1(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  _BalancePill(status: status, isDark: isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _GroupBalanceStatus _statusFor(double balance) {
    if (balance > 0) {
      return _GroupBalanceStatus.owed(balance);
    }
    if (balance < 0) {
      return _GroupBalanceStatus.owes(balance);
    }
    return const _GroupBalanceStatus.settled();
  }

  String _semanticLabel(_GroupBalanceStatus status) {
    final base = 'Group ${group.name}, ${group.memberCount} members';
    return switch (status) {
      _GroupBalanceStatusSettled() => '$base, all settled up.',
      _GroupBalanceStatusOwed(:final amount) =>
        '$base, you are owed ${group.currency}${amount.abs().toStringAsFixed(0)}.',
      _GroupBalanceStatusOwes(:final amount) =>
        '$base, you owe ${group.currency}${amount.abs().toStringAsFixed(0)}.',
    };
  }
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.group, required this.isDark});

  final GroupModel group;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider(isDark).withValues(alpha: 0.6),
        ),
      ),
      child: GroupCoverThumb(
        coverImageBase64: group.coverImageBase64,
        coverEmoji: group.coverEmoji,
        size: 44,
        borderRadius: 12,
        emojiFontSize: 22,
        fallbackIconColor: AppColors.textSecondary(isDark),
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.status, required this.isDark});

  final _GroupBalanceStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (status) {
      _GroupBalanceStatusSettled() => (
          AppColors.textSecondary(isDark),
          Icons.check_rounded,
          'Settled',
        ),
      _GroupBalanceStatusOwed(:final amount) => (
          AppColors.success,
          Icons.arrow_upward_rounded,
          _formatAmount(amount, positive: true),
        ),
      _GroupBalanceStatusOwes(:final amount) => (
          AppColors.warning,
          Icons.arrow_downward_rounded,
          _formatAmount(amount, positive: false),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption(isDark).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount, {required bool positive}) {
    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount.abs());
    return positive ? '+$formatted' : '-$formatted';
  }
}

sealed class _GroupBalanceStatus {
  const _GroupBalanceStatus();

  const factory _GroupBalanceStatus.settled() = _GroupBalanceStatusSettled;
  const factory _GroupBalanceStatus.owed(double amount) =
      _GroupBalanceStatusOwed;
  const factory _GroupBalanceStatus.owes(double amount) =
      _GroupBalanceStatusOwes;
}

class _GroupBalanceStatusSettled extends _GroupBalanceStatus {
  const _GroupBalanceStatusSettled();
}

class _GroupBalanceStatusOwed extends _GroupBalanceStatus {
  const _GroupBalanceStatusOwed(this.amount);
  final double amount;
}

class _GroupBalanceStatusOwes extends _GroupBalanceStatus {
  const _GroupBalanceStatusOwes(this.amount);
  final double amount;
}
