import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/avatar_picker_widget.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _phoneController.text.trim();
    final ok = await ref.read(authProvider.notifier).register(
          name: _nameController.text,
          phone: phone,
          email: _emailController.text,
        );
    if (!mounted || !ok) return;
    context.push('/verify-otp?phone=${Uri.encodeQueryComponent(phone)}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: screenWidth < 600
          ? _buildMobileLayout(isDark, authState)
          : screenWidth < 1100
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
                    'Smart expense splitting\nfor modern groups',
                    textAlign: TextAlign.center,
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
                child: _buildFormContent(isDark, authState),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(bool isDark, AuthData authState) {
    final loading = authState.state == AuthState.loading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AvatarPickerWidget(
              onImageSelected: (image) => setState(() => _selectedImage = image),
              selectedImage: _selectedImage,
              size: 100,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text('Create Account', style: AppTextStyles.headline2(isDark)),
                const SizedBox(height: 8),
                Text(
                  'Join thousands splitting smart',
                  style: AppTextStyles.caption(isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AppTextField(
            label: 'Full Name',
            hint: 'John Doe',
            controller: _nameController,
            prefixIcon: Icons.person_rounded,
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Name is required';
              if (v.length < 2) return 'Name is too short';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
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
              if (v.isEmpty) return 'Phone is required';
              if (!RegExp(r'^(\+\d{10,15}|\d{10})$').hasMatch(v)) {
                return 'Enter 10 digits or +<country><number>';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email (optional)',
            hint: 'john@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_rounded,
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return null;
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
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
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Create Account',
              onPressed: loading ? null : _handleRegister,
              isLoading: loading,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: AppTextStyles.body2(isDark),
                ),
                TextButton(
                  onPressed: loading ? null : () => context.go('/login'),
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
