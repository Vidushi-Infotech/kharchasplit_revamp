import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../text/currency_text.dart';

/// Compact hero balance card with a teal gradient and inline status.
class BalanceCard extends StatelessWidget {
  final double totalBalance;
  final String currency;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    required this.totalBalance,
    this.currency = '₹',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(totalBalance);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.tealLight,
                  AppColors.tealDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.tealDark.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: -30,
                  right: -20,
                  child: _BackdropOrb(size: 120, opacity: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'OVERALL BALANCE',
                              style: AppTextStyles.caption(false).copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            CurrencyText(
                              totalBalance,
                              currency: currency,
                              textStyle: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              animated: true,
                              overrideColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusBadge(status: status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _BalanceStatus _statusFor(double amount) {
    if (amount > 0) return _BalanceStatus.owed;
    if (amount < 0) return _BalanceStatus.owes;
    return _BalanceStatus.settled;
  }
}

enum _BalanceStatus { settled, owed, owes }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _BalanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (status) {
      _BalanceStatus.settled => (Icons.check_circle_rounded, 'Settled'),
      _BalanceStatus.owed => (Icons.trending_up_rounded, "You're owed"),
      _BalanceStatus.owes => (Icons.trending_down_rounded, 'You owe'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
