import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Hero "component previews" for the onboarding tour. Each one is a tightly
/// styled, Flutter-built mini mockup of the real feature — it gives the
/// slide the same component-forward feel as 21st.dev (real UI rather than a
/// generic icon).
///
/// All three are designed against a dark backdrop and use the brand teal as
/// the primary accent, with a slide-specific secondary tone for contrast.

const Color _onSurface = Color(0xFFE8EBF0);
const Color _onSurfaceMuted = Color(0xFF8A93A0);
const Color _surface = Color(0xFF161B22);
const Color _surfaceElev = Color(0xFF1D232C);
const Color _border = Color(0x1FFFFFFF); // white 12%

BoxDecoration _previewCardDecoration({Color glow = AppColors.tealDark}) {
  return BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: _border, width: 1),
    boxShadow: [
      BoxShadow(
        color: glow.withValues(alpha: 0.28),
        blurRadius: 48,
        spreadRadius: -8,
        offset: const Offset(0, 24),
      ),
      const BoxShadow(
        color: Color(0x66000000),
        blurRadius: 24,
        offset: Offset(0, 16),
      ),
    ],
  );
}

// --------------------------------------------------------------------------
// Slide 1 — Invite from contacts (WhatsApp fallback chip)
// --------------------------------------------------------------------------

class InvitePreview extends StatelessWidget {
  const InvitePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _previewCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SectionLabel(text: 'INVITE FRIENDS'),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.greenLight.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ContactRow(
            initials: 'A',
            name: 'Aarav Patel',
            phone: '+91 98765 43210',
            badge: _Badge.onApp,
          ),
          const SizedBox(height: 10),
          const _ContactRow(
            initials: 'R',
            name: 'Riya Mehta',
            phone: '+91 91234 56780',
            badge: _Badge.onApp,
          ),
          const SizedBox(height: 10),
          const _ContactRow(
            initials: 'V',
            name: 'Vikram Singh',
            phone: '+91 89999 00011',
            badge: _Badge.email,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.initials,
    required this.name,
    required this.phone,
    required this.badge,
  });

  final String initials;
  final String name;
  final String phone;
  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.tealDark.withValues(alpha: 0.22),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: _onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _onSurfaceMuted,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (badge == _Badge.onApp) const _ChipOnApp() else const _ChipEmail(),
      ],
    );
  }
}

enum _Badge { onApp, email }

class _ChipOnApp extends StatelessWidget {
  const _ChipOnApp();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tealDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Add',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Pill shown on unregistered contacts — the app sends them an SMTP email
/// invite (no SMS / WhatsApp path yet).
class _ChipEmail extends StatelessWidget {
  const _ChipEmail();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tealDark.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.tealDark.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mail_outline_rounded,
              size: 11, color: AppColors.greenLight),
          const SizedBox(width: 4),
          Text(
            'Add & Invite',
            style: TextStyle(
              color: AppColors.greenLight,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Slide 2 — Split an expense (amount + breakdown)
// --------------------------------------------------------------------------

class SplitPreview extends StatelessWidget {
  const SplitPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _previewCardDecoration(glow: const Color(0xFF6C8AE6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(text: 'NEW EXPENSE'),
          const SizedBox(height: 14),
          const Text(
            'Dinner at Cafe Bombay',
            style: TextStyle(
              color: _onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹',
                style: TextStyle(
                  color: _onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '1,240',
                style: TextStyle(
                  color: _onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _surfaceElev,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 12, color: _onSurfaceMuted),
                    SizedBox(width: 4),
                    Text(
                      'Equally',
                      style: TextStyle(
                        color: _onSurfaceMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _border),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _SplitChip(initials: 'S', amount: '₹413'),
              _SplitChip(initials: 'A', amount: '₹413'),
              _SplitChip(initials: 'R', amount: '₹414'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SplitChip extends StatelessWidget {
  const _SplitChip({required this.initials, required this.amount});
  final String initials;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.tealDark.withValues(alpha: 0.22),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: _onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: const TextStyle(
            color: _onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Slide 3 — Settle Up (balance + tap-to-confirm)
// --------------------------------------------------------------------------

class SettlePreview extends StatelessWidget {
  const SettlePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _previewCardDecoration(glow: AppColors.greenLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(text: 'YOUR BALANCE'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceTile(
                  label: 'You owe',
                  amount: '₹0',
                  accent: AppColors.warningOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceTile(
                  label: "You're owed",
                  amount: '₹827',
                  accent: AppColors.greenLight,
                  emphasized: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceElev,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.tealDark.withValues(alpha: 0.22),
                  ),
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: _onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Aarav owes you',
                        style: TextStyle(
                          color: _onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'For dinner · 2 days ago',
                        style: TextStyle(
                          color: _onSurfaceMuted,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 12, color: Color(0xFF0E2D14)),
                      SizedBox(width: 4),
                      Text(
                        'Settle',
                        style: TextStyle(
                          color: Color(0xFF0E2D14),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.amount,
    required this.accent,
    this.emphasized = false,
  });

  final String label;
  final String amount;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: emphasized
            ? accent.withValues(alpha: 0.10)
            : _surfaceElev,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasized ? accent.withValues(alpha: 0.4) : _border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _onSurfaceMuted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              color: emphasized ? accent : _onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.6,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Tiny shared label
// --------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _onSurfaceMuted,
        fontWeight: FontWeight.w700,
        fontSize: 10.5,
        letterSpacing: 1.4,
      ),
    );
  }
}
