import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/models.dart';

/// One person's net balance vs. the current user, used by the carousel.
class BalanceCardData {
  const BalanceCardData({
    required this.member,
    required this.amount,
    required this.iOweThem,
    this.isMe = false,
    this.settled = false,
    this.settleAmount = 0,
    this.pendingAmount = 0,
  });

  /// The group member this card represents.
  final UserModel member;

  /// Always a positive magnitude (0 when [settled]). This is the full net you
  /// owe / are owed.
  final double amount;

  /// true  → the current user owes [member] this much (for [isMe], "you owe")
  /// false → [member] owes the current user this much (for [isMe], "you are
  ///         owed")
  final bool iOweThem;

  /// This card is the current user's own card.
  final bool isMe;

  /// No outstanding balance — shown greyed out with no action.
  final bool settled;

  /// The amount Settle Up should actually request = [amount] minus what's
  /// already in a pending (unconfirmed) settlement to this person. When ≤ 0,
  /// everything owed is already in flight, so Settle Up is hidden.
  final double settleAmount;

  /// How much of [amount] is already awaiting confirmation (pending).
  final double pendingAmount;
}

/// Horizontally swipeable cards summarising per-person balances in a group —
/// mirroring the dashboard's group cards. Each card shows the person's first
/// name, whether you owe them / they owe you, the amount, and a Settle Up /
/// Remind action. The caller sorts [entries] (highest amount first).
class BalanceSummaryCards extends StatelessWidget {
  const BalanceSummaryCards({
    super.key,
    required this.entries,
    required this.onTap,
    required this.onSettle,
    required this.onRemind,
    this.horizontalPadding = 16,
  });

  final List<BalanceCardData> entries;

  /// Card body tapped — open the person's settlement view.
  final void Function(BalanceCardData entry) onTap;

  /// "Settle Up" pressed (shown when you owe them).
  final void Function(BalanceCardData entry) onSettle;

  /// "Remind" pressed (shown when they owe you).
  final void Function(BalanceCardData entry) onRemind;

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (entries.isEmpty) return const SizedBox.shrink();

    // Compact carousel — 3 full cards visible + a peek of the 4th on every
    // phone we support (~360 px small Androids up to ~430 px iPhone 17
    // Pro Max). Card width is derived from the available width so the peek
    // ratio stays consistent across devices and OS versions.
    //
    // Math: usable = screen − (horizontalPadding * 2) − (separator * 2.5)
    //       cardWidth = usable / 3.5   (3 visible + 0.5 peek)
    // The .clamp keeps a sane floor/ceiling so very narrow / very wide
    // viewports (foldables, tablets) still look reasonable.
    const separator = 10.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth =
        ((screenWidth - horizontalPadding * 2 - separator * 2.5) / 3.5)
            .clamp(96.0, 132.0);

    // Height scales with the user's accessibility text size. Clamp tighter
    // than before so the compact card doesn't grow back to its old size on
    // a huge font scale. iOS still renders ~5 % taller than Android for
    // the same scale, but the spec headroom (action button + tight gaps)
    // absorbs that without clipping. Pending sub-line was removed — it
    // surfaces inside the settlement detail instead.
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
    final height = 152.0 * textScale;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: separator),
        itemBuilder: (_, i) => SizedBox(
          width: cardWidth,
          child: _BalancePersonCard(
            data: entries[i],
            isDark: isDark,
            onTap: () => onTap(entries[i]),
            onSettle: () => onSettle(entries[i]),
            onRemind: () => onRemind(entries[i]),
          ),
        ),
      ),
    );
  }
}

class _BalancePersonCard extends StatelessWidget {
  const _BalancePersonCard({
    required this.data,
    required this.isDark,
    required this.onTap,
    required this.onSettle,
    required this.onRemind,
  });

  final BalanceCardData data;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onSettle;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final neutral = AppColors.textSecondary(isDark);
    final accent = data.settled
        ? neutral
        : (data.iOweThem ? AppColors.warning : AppColors.success);
    final label = data.settled
        ? 'all settled'
        : data.isMe
        ? (data.iOweThem ? 'you owe' : 'you are owed')
        : (data.iOweThem ? 'you owe' : 'owes you');
    final firstName = data.isMe
        ? 'You'
        : (data.member.name.trim().isEmpty
              ? data.member.name
              : data.member.name.trim().split(' ').first);
    final showAction = !data.isMe && !data.settled;

    // Settle Up only for the not-yet-pending amount; once everything owed is
    // already in a pending settlement, show a non-actionable "Pending" chip
    // instead. Remind stays for amounts they owe me.
    Widget? actionWidget;
    if (showAction) {
      if (data.iOweThem) {
        if (data.settleAmount > 0.01) {
          actionWidget = _CardAction(
            label: 'Settle Up',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.tealDark,
            onTap: onSettle,
          );
        } else if (data.pendingAmount > 0.01) {
          actionWidget = const _CardStatus(
            label: 'Pending',
            icon: Icons.schedule_rounded,
            color: AppColors.warning,
          );
        }
      } else {
        actionWidget = _CardAction(
          label: 'Remind',
          icon: Icons.notifications_active_rounded,
          color: AppColors.brand,
          onTap: onRemind,
        );
      }
    }

    // No hardcoded width here — the parent ListView sizes us via a SizedBox
    // (3.5 cards visible). Tight 10 px padding + smaller avatar + smaller
    // type collapses card height ~232 → ~152 without losing the action
    // affordance. Pending sub-line removed for breathing room — that detail
    // lives inside the settlement detail screen.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AvatarWidget(
                    name: data.member.name,
                    imageUrl: data.member.avatarUrl,
                    radius: 13,
                  ),
                  const Spacer(),
                  Icon(
                    data.settled
                        ? Icons.check_rounded
                        : (data.iOweThem
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded),
                    size: 14,
                    color: accent,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.settled
                    ? 'Settled'
                    : CurrencyFormatter.format(data.amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body1(isDark).copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (actionWidget != null) ...[
                const Spacer(),
                actionWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact, full-width NON-actionable status chip (e.g. "Pending") shown when
/// the whole owed amount is already awaiting confirmation.
class _CardStatus extends StatelessWidget {
  const _CardStatus({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, full-width action button used at the bottom of a balance card.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 26,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
