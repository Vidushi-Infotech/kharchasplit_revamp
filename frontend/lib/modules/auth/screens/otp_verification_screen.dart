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

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _resendCooldownSeconds = 30;

  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _resendIn = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

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

  Future<void> _handleVerify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(authProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: _otpController.text,
        );
    if (!mounted || !ok) return;
    context.go('/home/dashboard');
  }

  Future<void> _handleResend() async {
    if (_resendIn > 0) return;
    final ok = await ref
        .read(authProvider.notifier)
        .requestLoginOtp(widget.phone);
    if (!mounted) return;
    if (ok) {
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new OTP has been sent.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
          color: AppColors.textPrimary(isDark),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 600 ? 20 : 32,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildContent(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final authState = ref.watch(authProvider);
    final loading = authState.state == AuthState.loading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Verify your phone', style: AppTextStyles.headline2(isDark)),
          const SizedBox(height: 8),
          Text(
            'Enter the OTP sent to ${_maskedPhone(widget.phone)}',
            style: AppTextStyles.caption(isDark),
          ),
          const SizedBox(height: 40),
          AppTextField(
            label: 'OTP',
            hint: '6-digit code',
            controller: _otpController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.lock_outline_rounded,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Enter the OTP';
              if (v.length < 4) return 'OTP looks too short';
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (authState.state == AuthState.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                authState.errorMessage ?? 'Verification failed',
                style: AppTextStyles.error(isDark),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Verify & Continue',
              onPressed: loading ? null : _handleVerify,
              isLoading: loading,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: (_resendIn > 0 || loading) ? null : _handleResend,
              child: Text(
                _resendIn > 0
                    ? 'Resend OTP in ${_resendIn}s'
                    : 'Resend OTP',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: _resendIn > 0
                      ? AppColors.textSecondary(isDark)
                      : AppColors.tealDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskedPhone(String phone) {
    if (phone.length < 4) return phone;
    final tail = phone.substring(phone.length - 4);
    return '••• ••• $tail';
  }
}
