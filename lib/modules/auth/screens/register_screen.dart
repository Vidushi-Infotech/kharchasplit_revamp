import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../core/responsive/responsive_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/avatar_picker_widget.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../state/auth_provider.dart';
import '../widgets/password_strength_widget.dart';
import '../widgets/referral_code_field.dart';
import '../widgets/social_auth_buttons.dart';

/// Register screen with profile image, name, email, phone, password, referral code
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();

  File? _selectedImage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authProvider.notifier).register(
            fullName: _nameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
            referralCode: _referralController.text.isEmpty ? null : _referralController.text,
          );
      // Navigate to home after successful registration
      if (mounted && ref.read(authProvider).state == AuthState.success) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: isMobile
          ? _buildMobileLayout(isDark, authState)
          : isTablet
              ? _buildTabletLayout(isDark, authState)
              : _buildWebLayout(isDark, authState),
    );
  }

  Widget _buildMobileLayout(bool isDark, AuthData authState) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _buildFormContent(isDark, authState),
      ),
    );
  }

  Widget _buildTabletLayout(bool isDark, AuthData authState) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildFormContent(isDark, authState),
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout(bool isDark, AuthData authState) {
    return Row(
      children: [
        // Left brand panel
        Expanded(
          child: Container(
            color: AppColors.tealDark,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Kharcha Split',
                    style: AppTextStyles.headline1(true),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Smart expense splitting\nfor modern groups',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1(true),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right form panel
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildFormContent(isDark, authState),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(bool isDark, AuthData authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar picker - centered
          Center(
            child: AvatarPickerWidget(
              onImageSelected: (image) {
                setState(() => _selectedImage = image);
              },
              selectedImage: _selectedImage,
              size: 100,
            ),
          ),
          const SizedBox(height: 32),

          // Heading - centered
          Center(
            child: Column(
              children: [
                Text(
                  'Create Account',
                  style: AppTextStyles.headline2(isDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join thousands splitting smart',
                  style: AppTextStyles.caption(isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Social auth buttons
          SocialAuthButtons(
            onGooglePressed: () {},
            onFacebookPressed: () {},
            isLoading: authState.state == AuthState.loading,
          ),
          const SizedBox(height: 32),

          // Full Name
          AppTextField(
            label: 'Full Name',
            hint: 'John Doe',
            controller: _nameController,
            prefixIcon: Icons.person_rounded,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Name is required';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          AppTextField(
            label: 'Email',
            hint: 'john@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_rounded,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Email is required';
              if (!value!.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number
          AppTextField(
            label: 'Phone Number',
            hint: '9876543210',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_rounded,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Phone is required';
              if (value!.length != 10) return 'Enter valid 10-digit number';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          AppTextField(
            label: 'Password',
            hint: 'Min. 8 characters',
            controller: _passwordController,
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_rounded,
            suffixIcon: _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            onSuffixIconPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Password is required';
              if (value!.length < 8) return 'Min. 8 characters';
              return null;
            },
          ),
          PasswordStrengthWidget(password: _passwordController.text),
          const SizedBox(height: 16),

          // Confirm Password
          AppTextField(
            label: 'Confirm Password',
            hint: 'Re-enter password',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            prefixIcon: Icons.lock_rounded,
            suffixIcon: _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            onSuffixIconPressed: () {
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
            },
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Confirm password';
              if (value != _passwordController.text) return 'Passwords must match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Referral code (collapsible)
          ReferralCodeField(controller: _referralController),
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

          // Register button
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Create Account',
              onPressed: _handleRegister,
              isLoading: authState.state == AuthState.loading,
            ),
          ),
          const SizedBox(height: 20),

          // Login link
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: AppTextStyles.body2(isDark),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Login',
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
