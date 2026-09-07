import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/avatar_picker.dart';
import '../../auth/state/auth_provider.dart';
import '../widgets/email_verify_sheet.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _saving = false;

  /// Base64 of the freshly-picked image (no data URL prefix). Null until the
  /// user picks a new photo this session.
  String? _newAvatarBase64;
  Uint8List? _newAvatarBytes; // for preview
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    // The verify row below the field depends on whether the typed address
    // still matches the saved one.
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final result = await pickAndCropAvatar(context);
      if (result == null) return;
      if (!mounted) return;
      setState(() {
        _newAvatarBytes = result.bytes;
        _newAvatarBase64 = result.base64;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not pick image: $e', success: false);
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();

    final nameChanged = newName != user.name;
    final emailChanged = newEmail != (user.email);
    final avatarChanged = _newAvatarBase64 != null;

    if (!nameChanged && !emailChanged && !avatarChanged) {
      _showSnack('Nothing to save', success: false);
      return;
    }

    setState(() => _saving = true);
    final ok = await ref.read(authProvider.notifier).updateProfile(
          name: nameChanged ? newName : null,
          email: emailChanged ? newEmail : null,
          profileImageBase64: _newAvatarBase64,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _showSnack('Profile updated', success: true);
      if (mounted) context.pop();
    } else {
      final err = ref.read(authProvider).errorMessage ??
          'Could not update profile';
      _showSnack(err, success: false);
    }
  }

  void _showSnack(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        title: 'Edit profile',
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 1100 ? 640 : 760,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        if (_newAvatarBytes != null)
                          CircleAvatar(
                            radius: 44,
                            backgroundImage: MemoryImage(_newAvatarBytes!),
                          )
                        else
                          AvatarWidget(
                            name: user?.name ?? 'User',
                            imageUrl: user?.avatarUrl,
                            radius: 44,
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _pickingImage ? null : _pickAvatar,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.tealDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.background(isDark),
                                    width: 3,
                                  ),
                                ),
                                child: _pickingImage
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_newAvatarBytes != null) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _newAvatarBytes = null;
                          _newAvatarBase64 = null;
                        }),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Discard new photo'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _SectionLabel(label: 'NAME', isDark: isDark),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _nameController,
                    isDark: isDark,
                    hint: 'Your full name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.length < 2) return 'Name must be at least 2 characters';
                      if (s.length > 255) return 'Name is too long';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(label: 'EMAIL', isDark: isDark),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _emailController,
                    isDark: isDark,
                    hint: 'your@email.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null; // optional
                      final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRe.hasMatch(s)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  if (user != null && user.email.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _EmailVerifyRow(
                      isDark: isDark,
                      verified: user.isEmailVerified,
                      // A changed address must be saved first — verifying
                      // would otherwise send the code to the old one.
                      dirty: _emailController.text.trim() != user.email.trim(),
                      onVerify: () => EmailVerifySheet.confirmAndShow(
                        context,
                        email: user.email,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _SectionLabel(label: 'PHONE', isDark: isDark),
                  const SizedBox(height: 8),
                  _ReadOnlyField(
                    isDark: isDark,
                    icon: Icons.phone_rounded,
                    value: user?.phone ?? '',
                    hintIfEmpty: 'Not set',
                    lockedHint: "Phone can't be changed",
                  ),
                  const SizedBox(height: 32),
                  _GradientSaveButton(
                    isDark: isDark,
                    label: 'Save changes',
                    loading: _saving,
                    onTap: _saving ? null : _handleSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.isDark,
    required this.title,
    required this.onBack,
  });

  final bool isDark;
  final String title;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background(isDark),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
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
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status line under the email field: Verified / Not verified + Verify
/// button / "save first" hint when the address has been edited.
class _EmailVerifyRow extends StatelessWidget {
  const _EmailVerifyRow({
    required this.isDark,
    required this.verified,
    required this.dirty,
    required this.onVerify,
  });

  final bool isDark;
  final bool verified;
  final bool dirty;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (dirty) {
      return Text(
        'Save changes to verify the new address',
        style: AppTextStyles.caption(isDark)
            .copyWith(color: AppColors.textSecondary(isDark)),
      );
    }
    final color = verified ? AppColors.success : AppColors.warning;
    return Row(
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.error_outline_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            verified ? 'Email verified' : 'Email not verified',
            style: AppTextStyles.caption(isDark)
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        if (!verified)
          OutlinedButton(
            onPressed: onVerify,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Verify'),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.isDark,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final bool isDark;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.body1(isDark).copyWith(fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.cardBg(isDark),
        isDense: true,
        hintText: hint,
        hintStyle: AppTextStyles.body1(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: AppColors.textSecondary(isDark),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.tealDark.withValues(alpha: 0.45),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.warning),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.warning, width: 1.4),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.isDark,
    required this.icon,
    required this.value,
    required this.hintIfEmpty,
    required this.lockedHint,
  });

  final bool isDark;
  final IconData icon;
  final String value;
  final String hintIfEmpty;
  final String lockedHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider(isDark).withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isEmpty ? hintIfEmpty : value,
                  style: AppTextStyles.body1(isDark).copyWith(
                    color: value.isEmpty
                        ? AppColors.textSecondary(isDark)
                        : AppColors.textPrimary(isDark),
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 6),
          child: Text(
            lockedHint,
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientSaveButton extends StatelessWidget {
  const _GradientSaveButton({
    required this.isDark,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final bool isDark;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.tealLight, AppColors.tealDark],
                    )
                  : null,
              color: enabled ? null : AppColors.cardBg(isDark),
              border: enabled
                  ? null
                  : Border.all(color: AppColors.divider(isDark)),
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.tealDark.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: enabled
                              ? Colors.white
                              : AppColors.textSecondary(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
