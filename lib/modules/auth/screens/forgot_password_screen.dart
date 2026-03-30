import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../state/auth_provider.dart';

/// Forgot password screen with 2-step flow
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _step2 = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSendReset() {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }
    // In real implementation, this would verify email on backend
    setState(() => _step2 = true);
    _startResendCountdown();
  }

  void _handleResetPassword() async {
    if (_codeController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    await ref.read(authProvider.notifier).resetPassword(
      email: _emailController.text,
      code: _codeController.text,
      newPassword: _passwordController.text,
    );

    if (mounted && ref.read(authProvider).state == AuthState.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful')),
      );
      context.go('/login');
    }
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
    final authState = ref.watch(authProvider);

    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tealDark.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              size: 50,
              color: AppColors.tealDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Create New Password',
            style: AppTextStyles.headline2(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Enter the code from your email',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark),
          ),
        ),
        const SizedBox(height: 32),

        // Reset Code
        AppTextField(
          label: 'Reset Code',
          controller: _codeController,
          keyboardType: TextInputType.text,
          prefixIcon: Icons.mail_outline_rounded,
          hint: '6-digit code',
        ),
        const SizedBox(height: 16),

        // New Password
        AppTextField(
          label: 'New Password',
          controller: _passwordController,
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_rounded,
          suffixIcon: _obscurePassword
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          onSuffixIconPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        const SizedBox(height: 16),

        // Confirm Password
        AppTextField(
          label: 'Confirm Password',
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          prefixIcon: Icons.lock_rounded,
          suffixIcon: _obscureConfirmPassword
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          onSuffixIconPressed: () {
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
          },
        ),
        const SizedBox(height: 24),

        // Error message
        if (authState.state == AuthState.error)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              authState.errorMessage ?? 'An error occurred',
              style: AppTextStyles.error(isDark),
              textAlign: TextAlign.center,
            ),
          ),

        // Reset button
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Reset Password',
            onPressed: _handleResetPassword,
            isLoading: authState.state == AuthState.loading,
          ),
        ),
        const SizedBox(height: 16),

        // Back to login
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
}
