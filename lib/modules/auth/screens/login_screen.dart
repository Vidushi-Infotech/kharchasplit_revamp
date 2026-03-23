import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../state/auth_provider.dart';
import '../widgets/social_auth_buttons.dart';

/// Login screen with email and password
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  /// Compact layout for mobile devices (< 600px)
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

  /// Tablet layout (600-1100px)
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

  /// Web layout (> 1100px) with split panel
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text('Welcome Back', style: AppTextStyles.headline2(isDark)),
              const SizedBox(height: 8),
              Text('Sign in to continue', style: AppTextStyles.caption(isDark)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          label: 'Social login options - Google and Facebook buttons',
          child: SocialAuthButtons(
            onGooglePressed: () {},
            onFacebookPressed: () {},
            isLoading: authState.state == AuthState.loading,
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          textField: true,
          label: 'Email address input field',
          child: AppTextField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_rounded,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          textField: true,
          label: 'Password input field with visibility toggle',
          child: AppTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_rounded,
            suffixIcon: _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            onSuffixIconPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            label: 'Forgot password button - navigate to password recovery',
            child: TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: Text(
                'Forgot Password?',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.tealDark,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Semantics(
          button: true,
          label: 'Login button - sign in with email and password',
          child: SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Login',
              onPressed: () => context.go('/home/dashboard'),
              isLoading: authState.state == AuthState.loading,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ", style: AppTextStyles.body2(isDark)),
              Semantics(
                button: true,
                label: 'Register button - navigate to registration screen',
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(
                    'Register',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
