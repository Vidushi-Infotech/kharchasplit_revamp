import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_auth/smart_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _resendCooldownSeconds = 30;
  static const int _otpLength = 6;

  // Single hidden text field captures all 6 digits via paste / keyboard /
  // autofill. The visible row is just six "display-only" boxes rendered
  // from this controller's value. This avoids the Android-side autofill
  // indicator UI from drawing inside each per-digit TextField.
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _resendTimer;
  int _resendIn = _resendCooldownSeconds;
  String? _error;
  bool _autofillActive = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _startSmsAutofill();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_error != null) {
      setState(() => _error = null);
    } else {
      setState(() {});
    }
    if (_isComplete) _maybeSubmit();
  }

  /// Android-only: register an SMS User Consent listener. When a verification
  /// SMS arrives the OS shows a dialog asking the user to allow this app to
  /// read it; if they accept, the package returns the parsed digits.
  /// iOS is already handled natively via [AutofillHints.oneTimeCode] in the
  /// digit boxes (keyboard suggests the code above the input).
  Future<void> _startSmsAutofill() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_autofillActive) return;
    _autofillActive = true;
    try {
      final res = await SmartAuth.instance.getSmsWithUserConsentApi();
      if (!mounted) return;
      if (res.hasData) {
        final code = res.requireData.code;
        if (code != null) _setCode(code);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[OTP] SMS autofill failed: $e');
    } finally {
      _autofillActive = false;
    }
  }

  String get _code => _controller.text;
  bool get _isComplete => _code.length == _otpLength;

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendIn -= 1;
        if (_resendIn <= 0) t.cancel();
      });
    });
  }

  /// Drop incoming code (from SMS autofill, paste, etc.) into the
  /// shared controller. The listener handles auto-submit on completion.
  void _setCode(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    final clamped =
        cleaned.length > _otpLength ? cleaned.substring(0, _otpLength) : cleaned;
    _controller.text = clamped;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  Future<void> _maybeSubmit() async {
    if (!_isComplete) return;
    await _handleVerify();
  }

  Future<void> _handleVerify() async {
    if (!_isComplete) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    final ok = await ref.read(authProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: _code,
        );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = ref.read(authProvider).errorMessage ?? 'Verification failed';
      });
      return;
    }
    final needsSetup = ref.read(authProvider).needsProfileSetup;
    context.go(needsSetup ? '/profile-setup' : '/home/dashboard');
  }

  Future<void> _handleResend() async {
    if (_resendIn > 0) return;
    final ok = await ref
        .read(authProvider.notifier)
        .requestLoginOtp(widget.phone);
    if (!mounted) return;
    if (ok) {
      // Clear input and refocus
      _controller.text = '';
      _focus.requestFocus();
      setState(() => _error = null);
      _startResendCooldown();
      // Re-arm the Android SMS listener so the new OTP auto-fills too.
      _startSmsAutofill();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('A new OTP has been sent.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.tealDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final authState = ref.watch(authProvider);
    final loading = authState.state == AuthState.loading;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: Stack(
        children: [
          // Decorative blobs (same as login)
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
            child: Column(
              children: [
                _TopBar(
                  isDark: isDark,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/login'),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth < 600 ? 24 : 32,
                        vertical: 8,
                      ),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: screenWidth < 1100 ? 460 : 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Hero(
                              isDark: isDark,
                              phone: widget.phone,
                              onEdit: () =>
                                  context.canPop() ? context.pop() : null,
                            ),
                            const SizedBox(height: 32),
                            _OtpBoxes(
                              isDark: isDark,
                              controller: _controller,
                              focusNode: _focus,
                              length: _otpLength,
                              hasError: _error != null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _error!,
                                      style:
                                          AppTextStyles.caption(isDark).copyWith(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            _VerifyButton(
                              isDark: isDark,
                              enabled: _isComplete && !loading,
                              loading: loading,
                              onPressed: _handleVerify,
                            ),
                            const SizedBox(height: 18),
                            _ResendRow(
                              isDark: isDark,
                              secondsLeft: _resendIn,
                              loading: loading,
                              onResend: _handleResend,
                            ),
                          ],
                        ),
                      ),
                    ),
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

// Sentinel string keeps the iOS / Android autofill plumbing happy for
// one-time SMS codes without us needing to import flutter/services types
// at the call site.
const String otpOneTimeCode = AutofillHints.oneTimeCode;

// --------------------------------------------------------------------------
// Top bar with circular back button
// --------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isDark, required this.onBack});
  final bool isDark;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(isDark),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider(isDark)),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppColors.textPrimary(isDark),
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
// Hero — lock icon + headline + masked phone + "edit" link
// --------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({
    required this.isDark,
    required this.phone,
    required this.onEdit,
  });

  final bool isDark;
  final String phone;
  final VoidCallback onEdit;

  String _displayPhone() {
    // Keep readable but hide middle digits; e.g. +91 ••• ••• 7294
    if (phone.length < 4) return phone;
    final tail = phone.substring(phone.length - 4);
    if (phone.startsWith('+')) {
      final cc = phone.substring(0, phone.length - 10).replaceAll(' ', '');
      return '$cc ••• ••• $tail';
    }
    return '••• ••• $tail';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider(isDark)),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDark
                    .withValues(alpha: isDark ? 0.18 : 0.10),
                blurRadius: 22,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.sms_outlined,
              size: 26,
              color: AppColors.tealDark,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Enter verification code',
          style: AppTextStyles.headline2(isDark).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              height: 1.4,
              fontSize: 13.5,
            ),
            children: [
              const TextSpan(text: "We've sent a 6-digit code to "),
              TextSpan(
                text: _displayPhone(),
                style: AppTextStyles.body2(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onEdit,
          icon: Icon(
            Icons.edit_outlined,
            size: 13,
            color: AppColors.tealDark,
          ),
          label: Text(
            'Change number',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.tealDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// 6 separate digit boxes with auto-advance focus
// --------------------------------------------------------------------------

/// Visible 6-box OTP display that reads from a single shared [controller].
/// A fully-transparent TextField sits behind the boxes to capture the
/// actual input — paste, keyboard typing, iOS keyboard-suggest, and
/// Android autofill all flow through that one field, which sidesteps the
/// system-drawn per-field autofill indicator that was breaking the look.
class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({
    required this.isDark,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
  });

  final bool isDark;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_rebuild);
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _focusInput() {
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
    // Caret to end so the next typed digit appends.
    widget.controller.selection =
        TextSelection.collapsed(offset: widget.controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final boxWidth =
        (width.clamp(0.0, 460.0) - 24 * 2 - 10 * (widget.length - 1)) /
            widget.length;
    final clampedBox = boxWidth.clamp(40.0, 56.0);
    final value = widget.controller.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusInput,
      child: Stack(
        children: [
          // Visible row of 6 digit boxes.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              final digit = i < value.length ? value[i] : '';
              final isCurrent =
                  widget.focusNode.hasFocus && i == value.length;
              return _OtpBoxFace(
                isDark: widget.isDark,
                size: clampedBox,
                digit: digit,
                isCurrent: isCurrent,
                hasError: widget.hasError,
              );
            }),
          ),
          // Invisible TextField overlay — actually captures input.
          Positioned.fill(
            child: AutofillGroup(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                enableInteractiveSelection: false,
                showCursor: false,
                // Invisible text — visual digits are drawn by the boxes above.
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                  height: 1,
                ),
                cursorColor: Colors.transparent,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBoxFace extends StatelessWidget {
  const _OtpBoxFace({
    required this.isDark,
    required this.size,
    required this.digit,
    required this.isCurrent,
    required this.hasError,
  });

  final bool isDark;
  final double size;
  final String digit;
  final bool isCurrent;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final hasValue = digit.isNotEmpty;
    Color borderColor;
    double borderWidth;
    if (hasError) {
      borderColor = AppColors.warning.withValues(alpha: 0.7);
      borderWidth = 1.4;
    } else if (isCurrent) {
      borderColor = AppColors.tealDark;
      borderWidth = 1.6;
    } else if (hasValue) {
      borderColor = AppColors.tealDark.withValues(alpha: 0.45);
      borderWidth = 1.2;
    } else {
      borderColor = AppColors.divider(isDark);
      borderWidth = 1.0;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size + 4,
      decoration: BoxDecoration(
        color: hasValue
            ? AppColors.tealDark.withValues(alpha: isDark ? 0.10 : 0.06)
            : AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: hasValue
          ? Text(
              digit,
              style: AppTextStyles.headline2(isDark).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(isDark),
                letterSpacing: 0,
                height: 1.0,
              ),
            )
          : (isCurrent ? _BlinkingCaret(isDark: isDark) : null),
    );
  }
}

/// Soft blinking pseudo-caret for the currently-active empty box.
class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret({required this.isDark});
  final bool isDark;

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.tealDark,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Verify button (gradient when enabled)
// --------------------------------------------------------------------------

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
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
                        'Verify',
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
                        Icons.check_rounded,
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
// Resend row — "Didn't get it?" + Resend OTP / countdown
// --------------------------------------------------------------------------

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.isDark,
    required this.secondsLeft,
    required this.loading,
    required this.onResend,
  });

  final bool isDark;
  final int secondsLeft;
  final bool loading;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final canResend = secondsLeft <= 0 && !loading;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive it? ",
          style: AppTextStyles.body2(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            fontSize: 13,
          ),
        ),
        if (canResend)
          TextButton(
            onPressed: onResend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resend OTP',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.tealDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Resend in ${secondsLeft}s',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}
