import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../dashboard/state/dashboard_provider.dart';

/// Splitwise-style "Overall" balance card at the top of the Groups tab —
/// the summary the old Home dashboard used to carry.
///
/// * Owed on net  → "Overall, you are owed ₹X" (green)
/// * Owe on net   → "Overall, you owe ₹X" (red)
/// * Both ~zero   → "You are all settled up" (neutral)
///
/// When money flows both ways a secondary line splits it into
/// "You are owed ₹A · You owe ₹B"; each half opens its drill-down screen.
/// Loading shows a slim shimmer; an error hides the card (the groups list
/// below surfaces its own error state).
class OverallBalanceCard extends ConsumerWidget {
  const OverallBalanceCard({super.key});

  /// Balances below this are rounding noise, not money.
  static const double _epsilon = 0.005;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(dashboardProvider);
    // Keep the last good numbers on screen through refreshes and transient
    // errors; only a first load with nothing cached shows the shimmer.
    final data = async.value;
    if (data == null) {
      return async.isLoading ? _Skeleton(isDark: isDark) : const SizedBox();
    }

    final owed = data.youAreOwed;
    final owe = data.youOwe;
    final net = data.totalBalance;
    final hasOwed = owed > _epsilon;
    final hasOwe = owe > _epsilon;

    final String headline;
    final Color tone;
    if (net > _epsilon) {
      headline = AppStrings.overallYouAreOwed(_money(net));
      tone = AppColors.success;
    } else if (net < -_epsilon) {
      headline = AppStrings.overallYouOwe(_money(net));
      tone = AppColors.errorText(isDark);
    } else if (hasOwed || hasOwe) {
      // Debts cancel out across groups but still exist pair-by-pair, so
      // neither "settled up" nor "owed ₹0" is honest — let the split line
      // below carry the numbers.
      headline = AppStrings.balances;
      tone = AppColors.textSecondary(isDark);
    } else {
      headline = AppStrings.youAreAllSettledUp;
      tone = AppColors.textSecondary(isDark);
    }

    void open(String location) {
      HapticService.instance.selection();
      context.push(location);
    }

    // With only one direction in play the whole card is the shortcut.
    final VoidCallback? cardTap = hasOwed && !hasOwe
        ? () => open('/home/owed-to-me')
        : hasOwe && !hasOwed
        ? () => open('/home/i-owe')
        : null;

    return Semantics(
      container: true,
      button: cardTap != null,
      label: headline,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: cardTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: tone,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (cardTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary(isDark),
                      ),
                  ],
                ),
                if (hasOwed && hasOwe) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _SplitLink(
                        text: '${AppStrings.youAreOwed} ${_money(owed)}',
                        color: AppColors.success,
                        isDark: isDark,
                        onTap: () => open('/home/owed-to-me'),
                      ),
                      Text(
                        '  ·  ',
                        style: AppTextStyles.caption(
                          isDark,
                        ).copyWith(color: AppColors.textSecondary(isDark)),
                      ),
                      _SplitLink(
                        text: '${AppStrings.youOwe} ${_money(owe)}',
                        color: AppColors.errorText(isDark),
                        isDark: isDark,
                        onTap: () => open('/home/i-owe'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _money(double amount) =>
      CurrencyFormatter.format(amount.abs(), decimalPlaces: 0);
}

/// One tappable half of the "You are owed ₹A · You owe ₹B" line.
class _SplitLink extends StatelessWidget {
  const _SplitLink({
    required this.text,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final String text;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(
            text,
            style: AppTextStyles.body2(isDark).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              decoration: TextDecoration.underline,
              decorationColor: color.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double h) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: AppColors.divider(isDark),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.surface(isDark).withValues(alpha: 0.85),
        highlightColor: AppColors.surface(isDark).withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [bar(0.6, 16), const SizedBox(height: 10), bar(0.4, 12)],
        ),
      ),
    );
  }
}
