import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _phoneController.text.trim();
    final ok = await ref.read(authProvider.notifier).requestLoginOtp(phone);
    if (!mounted || !ok) return;
    context.push('/verify-otp?phone=${Uri.encodeQueryComponent(phone)}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: screenWidth < 600
          ? _buildCompactLayout(isDark)
          : screenWidth < 1100
              ? _buildTabletLayout(isDark)
              : _buildWebLayout(isDark),
    );
  }

  Widget _buildCompactLayout(bool isDark) {
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

  Widget _buildTabletLayout(bool isDark) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildFormContent(isDark),
          ),
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
    final authState = ref.watch(authProvider);
    final loading = authState.state == AuthState.loading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Text('Welcome Back', style: AppTextStyles.headline2(isDark)),
                const SizedBox(height: 8),
                Text(
                  'Sign in with your phone number',
                  style: AppTextStyles.caption(isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Semantics(
            textField: true,
            label: 'Phone number input — 10 digit Indian mobile',
            child: AppTextField(
              label: 'Phone Number',
              hint: '9876543210',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_rounded,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Phone number is required';
                if (!RegExp(r'^(\+\d{10,15}|\d{10})$').hasMatch(v)) {
                  return 'Enter 10 digits or +<country><number>';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          if (authState.state == AuthState.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                authState.errorMessage ?? 'Something went wrong',
                style: AppTextStyles.error(isDark),
                textAlign: TextAlign.center,
              ),
            ),
          Semantics(
            button: true,
            label: 'Send OTP — request a one-time code by SMS',
            child: SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Send OTP',
                onPressed: loading ? null : _handleSendOtp,
                isLoading: loading,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: AppTextStyles.body2(isDark),
                ),
                TextButton(
                  onPressed: loading ? null : () => context.go('/register'),
                  child: Text(
                    'Register',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w600,
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
