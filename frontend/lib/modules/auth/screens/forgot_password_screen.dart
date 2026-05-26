import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/auth_provider.dart';

/// Two-step password reset flow.
///
/// Step 1 — user enters their email; backend emails a 6-digit OTP.
/// Step 2 — user enters the OTP + a new password. On success the backend
/// auto-logs in and we route to the dashboard.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _step2 = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String? _error;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email);

  bool get _otpValid =>
      RegExp(r'^\d{4,10}$').hasMatch(_otpController.text.trim());

  bool get _newPwLongEnough => _newPasswordController.text.length >= 6;
  bool get _passwordsMatch =>
      _newPasswordController.text == _confirmController.text;

  bool get _step2Valid =>
      _otpValid && _newPwLongEnough && _passwordsMatch;

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _handleSendCode() async {
    setState(() => _error = null);
    if (!_emailValid) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }
    final ok =
        await ref.read(authProvider.notifier).requestPasswordReset(_email);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = ref.read(authProvider).errorMessage ??
          'Could not send code');
      return;
    }
    setState(() => _step2 = true);
    _startResendCountdown();
  }

  Future<void> _handleVerify() async {
    setState(() => _error = null);
    if (!_otpValid) {
      setState(() => _error = 'Enter the code from your email');
      return;
    }
    if (!_newPwLongEnough) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (!_passwordsMatch) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    final ok = await ref.read(authProvider.notifier).resetPassword(
          email: _email,
          otp: _otpController.text.trim(),
          newPassword: _newPasswordController.text,
          confirmPassword: _confirmController.text,
        );
    if (!mounted) return;
    if (!ok) {
      setState(() => _error =
          ref.read(authProvider).errorMessage ?? 'Could not reset password');
      return;
    }
    // Backend auto-logged us in. Route based on whether profile is complete.
    final auth = ref.read(authProvider);
    context.go(
        auth.needsProfileSetup ? '/profile-setup' : '/home/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final bottomInset = mq.viewInsets.bottom;
    final loading =
        ref.watch(authProvider).state == AuthState.loading;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      resizeToAvoidBottomInset: false,
      body: screenWidth < 1100
          ? _buildMobileLayout(isDark, loading, bottomInset)
          : _buildWebLayout(isDark, loading),
    );
  }

  Widget _buildMobileLayout(bool isDark, bool loading, double bottomInset) {
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary(isDark)),
                onPressed: loading
                    ? null
                    : () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
              ),
            ),
            const SizedBox(height: 16),
            _buildFormContent(isDark, loading),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout(bool isDark, bool loading) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: AppColors.tealDark,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Kharcha Split',
                      style: AppTextStyles.headline1(true)),
                  const SizedBox(height: 16),
                  Text(
                    'Smart expense splitting',
                    style: AppTextStyles.body1(true),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildFormContent(isDark, loading),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(bool isDark, bool loading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _step2
              ? _buildStep2(isDark, loading)
              : _buildStep1(isDark, loading),
        ),
      ],
    );
  }

  Widget _buildStep1(bool isDark, bool loading) {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tealDark.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.lock_open_rounded,
              size: 50,
              color: AppColors.tealDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('Forgot Password?',
              style: AppTextStyles.headline2(isDark)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            "Enter your registered email and we'll send a 6-digit code to reset your password.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark),
          ),
        ),
        const SizedBox(height: 32),
        AppTextField(
          label: 'Email Address',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_rounded,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorRow(isDark: isDark, message: _error!),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Send Reset Code',
            onPressed: loading ? null : _handleSendCode,
            isLoading: loading,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: loading ? null : () => context.go('/login'),
            child: Text(
              'Back to Login',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.tealDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(bool isDark, bool loading) {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tealDark.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.mark_email_read_rounded,
              size: 50,
              color: AppColors.tealDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child:
              Text('Check Your Email', style: AppTextStyles.headline2(isDark)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'If $_email is registered, a 6-digit code is on its way. Enter it below.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark),
          ),
        ),
        const SizedBox(height: 32),
        AppTextField(
          label: 'Reset Code',
          controller: _otpController,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.pin_outlined,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'New Password',
          controller: _newPasswordController,
          obscureText: _obscureNew,
          prefixIcon: Icons.lock_outline_rounded,
          suffixIcon:
              _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          onSuffixIconPressed: () =>
              setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Confirm Password',
          controller: _confirmController,
          obscureText: _obscureConfirm,
          prefixIcon: Icons.lock_outline_rounded,
          suffixIcon: _obscureConfirm
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onSuffixIconPressed: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorRow(isDark: isDark, message: _error!),
        ],
        const SizedBox(height: 20),
        if (_resendCountdown > 0)
          Center(
            child: Text(
              'Resend code in $_resendCountdown s',
              style: AppTextStyles.caption(isDark),
            ),
          )
        else
          Center(
            child: TextButton(
              onPressed: loading ? null : _handleSendCode,
              child: Text(
                'Resend Code',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Reset Password',
            onPressed: loading || !_step2Valid ? null : _handleVerify,
            isLoading: loading,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: loading
                ? null
                : () => setState(() {
                      _step2 = false;
                      _error = null;
                      _otpController.clear();
                      _newPasswordController.clear();
                      _confirmController.clear();
                      _resendTimer?.cancel();
                      _resendCountdown = 0;
                    }),
            child: Text(
              'Use a different email',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.tealDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.isDark, required this.message});
  final bool isDark;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline_rounded,
            size: 14, color: AppColors.warning),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
