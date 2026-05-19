import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/auth_provider.dart';

/// Public legal URLs. Tapping "Terms" / "Privacy Policy" in the footer
/// opens these in the user's browser.
const String _termsUrl = 'https://kharchasplit.com/terms-conditions';
const String _privacyUrl = 'https://kharchasplit.com/privacy-policy';

/// Open [url] in the system browser. Falls back silently if the platform
/// has no browser registered (extremely rare).
Future<void> _openExternal(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  /// Rebuild whenever the phone field changes so `_isValid` re-evaluates
  /// (enables the Continue button) and any pending error clears.
  void _onPhoneChanged() {
    if (!mounted) return;
    setState(() {
      if (_error != null) _error = null;
    });
  }

  bool get _isValid {
    final v = _phoneController.text.trim();
    if (v.isEmpty) return false;
    if (v.startsWith('+')) return RegExp(r'^\+\d{10,15}$').hasMatch(v);
    return RegExp(r'^\d{10}$').hasMatch(v);
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.trim();
    if (!_isValid) {
      setState(() => _error = phone.isEmpty
          ? 'Please enter your phone number'
          : 'Enter a 10-digit number or +country code');
      return;
    }
    final ok = await ref.read(authProvider.notifier).requestLoginOtp(phone);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = ref.read(authProvider).errorMessage ??
          'Could not send OTP');
      return;
    }
    context.push('/verify-otp?phone=${Uri.encodeQueryComponent(phone)}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final authState = ref.watch(authProvider);
    final loading = authState.state == AuthState.loading;
    final canContinue = _isValid && !loading;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: Stack(
        children: [
          // Subtle hero blob behind the top — gives the screen depth without
          // looking like a stock splash.
          Positioned(
            top: -120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealDark.withValues(
                    alpha: isDark ? 0.08 : 0.06,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning.withValues(
                    alpha: isDark ? 0.05 : 0.04,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth < 1100 ? 460 : 520,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      _Hero(isDark: isDark),
                      const SizedBox(height: 36),
                      _SectionLabel(
                        isDark: isDark,
                        text: 'PHONE NUMBER',
                      ),
                      const SizedBox(height: 8),
                      _PhoneField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        isDark: isDark,
                        hasError: _error != null,
                        onSubmitted: (_) => canContinue ? _handleContinue() : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppTextStyles.caption(isDark).copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      _ContinueButton(
                        isDark: isDark,
                        enabled: canContinue,
                        loading: loading,
                        onPressed: _handleContinue,
                      ),
                      const SizedBox(height: 18),
                      _HelperText(isDark: isDark),
                      const SizedBox(height: 32),
                      _TermsFooter(isDark: isDark),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Hero (logo + welcome text)
// --------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.divider(isDark),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDark.withValues(alpha: isDark ? 0.18 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Welcome',
          style: AppTextStyles.headline1(isDark).copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in or sign up with your phone number to start splitting expenses.',
          style: AppTextStyles.body2(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            height: 1.4,
            fontSize: 13.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Section label (uppercase overline)
// --------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.isDark, required this.text});
  final bool isDark;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Phone field — +91 prefix segment + 10-digit input
// --------------------------------------------------------------------------

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.hasError,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final bool hasError;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.warning.withValues(alpha: 0.6)
        : AppColors.divider(isDark);
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: hasError ? 1.4 : 1),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  '🇮🇳',
                  style: AppTextStyles.body1(isDark).copyWith(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  '+91',
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.divider(isDark),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.go,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              ],
              onSubmitted: onSubmitted,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                hintText: '98765 43210',
                hintStyle: AppTextStyles.body1(isDark).copyWith(
                  color: AppColors.textSecondary(isDark).withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Continue button — enabled gradient, disabled muted
// --------------------------------------------------------------------------

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.isDark,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool isDark;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: enabled
                  ? LinearGradient(
                      colors: [
                        AppColors.tealDark,
                        AppColors.tealDark.withValues(alpha: 0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: enabled ? null : AppColors.divider(isDark),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.tealDark
                            .withValues(alpha: isDark ? 0.30 : 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue',
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: enabled
                              ? Colors.white
                              : AppColors.textSecondary(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary(isDark),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Helper text + terms
// --------------------------------------------------------------------------

class _HelperText extends StatelessWidget {
  const _HelperText({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.sms_outlined,
          size: 14,
          color: AppColors.textSecondary(isDark),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            "We'll send a 6-digit code by SMS",
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsFooter extends StatefulWidget {
  const _TermsFooter({required this.isDark});
  final bool isDark;

  @override
  State<_TermsFooter> createState() => _TermsFooterState();
}

class _TermsFooterState extends State<_TermsFooter> {
  // Tap recognizers must persist for the widget's lifetime — recreating
  // them on every build leaks gesture arenas.
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openExternal(_termsUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openExternal(_privacyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final base = AppTextStyles.caption(isDark).copyWith(
      color: AppColors.textSecondary(isDark),
      fontSize: 11.5,
      height: 1.5,
    );
    final link = base.copyWith(
      color: AppColors.tealDark,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.tealDark.withValues(alpha: 0.4),
    );
    return Center(
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'By continuing you agree to our '),
            TextSpan(
              text: 'Terms',
              style: link,
              recognizer: _termsTap,
              semanticsLabel: 'Terms and conditions, opens in browser',
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: link,
              recognizer: _privacyTap,
              semanticsLabel: 'Privacy policy, opens in browser',
            ),
            const TextSpan(text: '.'),
          ],
          style: base,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
