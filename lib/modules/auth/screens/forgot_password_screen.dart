import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';

/// Forgot password screen with 2-step flow
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _step2 = false;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendReset() {
    setState(() => _step2 = true);
    _startResendCountdown();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _resendCountdown--);
      }
      return _resendCountdown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: screenWidth < 1100
          ? _buildMobileLayout(isDark)
          : _buildWebLayout(isDark),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildFormContent(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: AppColors.tealDark,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Kharcha Split', style: AppTextStyles.headline1(true)),
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
                child: _buildFormContent(isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text('Reset Password', style: AppTextStyles.headline2(isDark)),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 32),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
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
              ? _buildStep2(isDark)
              : _buildStep1(isDark),
        ),
      ],
    );
  }

  Widget _buildStep1(bool isDark) {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tealDark.withOpacity(0.1),
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
          child: Text(
            'Forgot Password?',
            style: AppTextStyles.headline2(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Enter your registered email and we\'ll send a reset link.',
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
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Send Reset Link',
            onPressed: _handleSendReset,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
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

  Widget _buildStep2(bool isDark) {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.greenLight.withOpacity(0.1),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 50,
              color: AppColors.greenLight,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('Check Your Email', style: AppTextStyles.headline2(isDark)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Reset link sent to ${_emailController.text}',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark),
          ),
        ),
        const SizedBox(height: 32),
        if (_resendCountdown > 0)
          Center(
            child: Text(
              'Resend in $_resendCountdown seconds',
              style: AppTextStyles.caption(isDark),
            ),
          )
        else
          Center(
            child: TextButton(
              onPressed: () {
                _handleSendReset();
              },
              child: Text(
                'Resend Email',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.tealDark,
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Back to Login',
            onPressed: () => context.go('/login'),
          ),
        ),
      ],
    );
  }
}
