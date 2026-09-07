import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/users/users_repository.dart';
import '../../auth/state/auth_provider.dart';

/// Bottom sheet for the optional email-verification flow.
///
/// Opening it requests a code straight away (one fewer tap), shows where it
/// went, and lets the user enter it. On success the auth state is refreshed
/// so the profile badge flips to "Verified" without a manual reload.
class EmailVerifySheet extends ConsumerStatefulWidget {
  const EmailVerifySheet({super.key, required this.email});

  final String email;

  static Future<void> show(BuildContext context, {required String email}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmailVerifySheet(email: email),
    );
  }

  @override
  ConsumerState<EmailVerifySheet> createState() => _EmailVerifySheetState();
}

class _EmailVerifySheetState extends ConsumerState<EmailVerifySheet> {
  final _otpController = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  bool _verifying = false;
  String? _error;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCode());
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  bool get _otpLooksValid =>
      RegExp(r'^\d{4,10}$').hasMatch(_otpController.text.trim());

  void _startCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  Future<void> _requestCode() async {
    final user = ref.read(authProvider).user;
    if (user == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(usersRepositoryProvider).requestEmailVerification(user.id);
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown(60);
    } on UsersApiException catch (e) {
      if (!mounted) return;
      // 429 = cooldown from a code sent moments ago; the old code is still
      // valid, so let the user type it rather than showing a dead end.
      setState(() {
        _sent = _sent || e.statusCode == 429;
        _error = e.message;
      });
      if (e.statusCode == 429) _startCooldown(60);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not send the code. Check your connection.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final user = ref.read(authProvider).user;
    if (user == null || _verifying || !_otpLooksValid) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref
          .read(usersRepositoryProvider)
          .confirmEmailVerification(user.id, _otpController.text.trim());
      // Pull the fresh profile so `emailVerifiedAt` lands in auth state and
      // secure storage; the profile badge re-renders from that.
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      HapticService.instance.success();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified')),
      );
    } on UsersApiException catch (e) {
      if (!mounted) return;
      HapticService.instance.error();
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      HapticService.instance.error();
      setState(() => _error = 'Could not verify. Check your connection.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Verify your email',
                style: AppTextStyles.headline3(isDark)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _sent
                    ? 'We sent a 6-digit code to ${widget.email}. Enter it below.'
                    : (_sending
                        ? 'Sending a code to ${widget.email}…'
                        : 'We\'ll send a 6-digit code to ${widget.email}.'),
                style: AppTextStyles.body2(isDark)
                    .copyWith(color: AppColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Verification code',
                controller: _otpController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.pin_outlined,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTextStyles.caption(isDark)
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Verify',
                isLoading: _verifying,
                onPressed: _otpLooksValid && !_verifying ? _verify : null,
              ),
              const SizedBox(height: 10),
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        'Resend code in $_resendCountdown s',
                        style: AppTextStyles.caption(isDark)
                            .copyWith(color: AppColors.textSecondary(isDark)),
                      )
                    : TextButton(
                        onPressed: _sending ? null : _requestCode,
                        child: Text(_sent ? 'Resend code' : 'Send code'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
