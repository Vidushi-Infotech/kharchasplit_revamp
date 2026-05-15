import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/auth_provider.dart';

/// First-time profile setup screen. Shown after a new user verifies their
/// OTP (or for any existing user whose `name` is still blank). Name +
/// email are required; profile photo is optional. Visual language matches
/// the redesigned login and OTP screens.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  Uint8List? _avatarBytes;
  String? _avatarBase64;
  bool _picking = false;
  bool _saving = false;
  String? _nameError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_clearNameErr);
    _emailController.addListener(_clearEmailErr);
  }

  @override
  void dispose() {
    _nameController.removeListener(_clearNameErr);
    _emailController.removeListener(_clearEmailErr);
    _nameController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _clearNameErr() {
    if (_nameError != null && mounted) setState(() => _nameError = null);
  }

  void _clearEmailErr() {
    if (_emailError != null && mounted) setState(() => _emailError = null);
  }

  bool get _isValid {
    final n = _nameController.text.trim();
    final e = _emailController.text.trim();
    if (n.length < 2) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  Future<void> _pickAvatar() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarBase64 = base64Encode(bytes);
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not pick image: $e', success: false);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _handleContinue() async {
    final n = _nameController.text.trim();
    final e = _emailController.text.trim();
    var hasErr = false;
    if (n.length < 2) {
      setState(() => _nameError =
          n.isEmpty ? 'Name is required' : 'Name is too short');
      hasErr = true;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      setState(() => _emailError =
          e.isEmpty ? 'Email is required' : 'Enter a valid email');
      hasErr = true;
    }
    if (hasErr) return;

    setState(() => _saving = true);
    final ok = await ref.read(authProvider.notifier).updateProfile(
          name: n,
          email: e,
          profileImageBase64: _avatarBase64,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      final err =
          ref.read(authProvider).errorMessage ?? 'Could not save profile';
      _showSnack(err, success: false);
      return;
    }
    if (mounted) context.go('/home/dashboard');
  }

  void _showSnack(String message, {required bool success}) {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final canContinue = _isValid && !_saving;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      // No back / app bar — this is a forced step.
      body: Stack(
        children: [
          // Decorative blobs — same as login + OTP for visual continuity
          Positioned(
            top: -120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealDark
                      .withValues(alpha: isDark ? 0.08 : 0.06),
                ),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning
                      .withValues(alpha: isDark ? 0.05 : 0.04),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth < 1100 ? 460 : 520,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _StepBadge(isDark: isDark),
                      const SizedBox(height: 20),
                      _Header(
                        isDark: isDark,
                        bytes: _avatarBytes,
                        picking: _picking,
                        onPickAvatar: _pickAvatar,
                        onRemoveAvatar: _avatarBytes == null
                            ? null
                            : () => setState(() {
                                  _avatarBytes = null;
                                  _avatarBase64 = null;
                                }),
                      ),
                      const SizedBox(height: 28),
                      _SectionLabel(isDark: isDark, text: 'FULL NAME'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        hint: 'Your name',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                        hasError: _nameError != null,
                        keyboardType: TextInputType.name,
                        capitalize: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                      if (_nameError != null)
                        _FieldError(text: _nameError!, isDark: isDark),
                      const SizedBox(height: 16),
                      _SectionLabel(isDark: isDark, text: 'EMAIL'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        hint: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                        isDark: isDark,
                        hasError: _emailError != null,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) =>
                            canContinue ? _handleContinue() : null,
                      ),
                      if (_emailError != null)
                        _FieldError(text: _emailError!, isDark: isDark),
                      const SizedBox(height: 28),
                      _ContinueButton(
                        isDark: isDark,
                        enabled: canContinue,
                        loading: _saving,
                        onPressed: _handleContinue,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'You can change these later from your profile.',
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Step badge
// --------------------------------------------------------------------------

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.tealDark.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.tealDark.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 12,
              color: AppColors.tealDark,
            ),
            const SizedBox(width: 6),
            Text(
              'PHONE VERIFIED',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.tealDark,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Hero — avatar + headline + subtitle
// --------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.isDark,
    required this.bytes,
    required this.picking,
    required this.onPickAvatar,
    required this.onRemoveAvatar,
  });

  final bool isDark;
  final Uint8List? bytes;
  final bool picking;
  final VoidCallback onPickAvatar;
  final VoidCallback? onRemoveAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AvatarPicker(
          isDark: isDark,
          bytes: bytes,
          picking: picking,
          onTap: onPickAvatar,
        ),
        const SizedBox(height: 16),
        Text(
          "Set up your profile",
          style: AppTextStyles.headline2(isDark).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Add your name and email so friends can find you.\nA profile photo is optional.',
          style: AppTextStyles.body2(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            height: 1.4,
            fontSize: 13.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (bytes != null && onRemoveAvatar != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onRemoveAvatar,
            icon: Icon(Icons.close_rounded, size: 13, color: AppColors.warning),
            label: Text(
              'Remove photo',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Avatar picker
// --------------------------------------------------------------------------

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.isDark,
    required this.bytes,
    required this.picking,
    required this.onTap,
  });

  final bool isDark;
  final Uint8List? bytes;
  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = bytes != null;
    return Semantics(
      button: true,
      label: hasPhoto ? 'Change profile photo' : 'Add profile photo',
      child: GestureDetector(
        onTap: picking ? null : onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Soft halo behind avatar
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tealDark
                    .withValues(alpha: isDark ? 0.10 : 0.06),
              ),
            ),
            // Avatar tile
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBg(isDark),
                border: Border.all(
                  color: hasPhoto
                      ? AppColors.tealDark.withValues(alpha: 0.4)
                      : AppColors.divider(isDark),
                  width: 1.5,
                ),
                image: hasPhoto
                    ? DecorationImage(
                        image: MemoryImage(bytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealDark
                        .withValues(alpha: isDark ? 0.16 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: hasPhoto
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 28,
                          color: AppColors.tealDark,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add photo',
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
            ),
            // Edit / loading fab
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background(isDark),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealDark.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: picking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        hasPhoto ? Icons.edit_rounded : Icons.add_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
              ),
            ),
            // "Optional" tag when no photo yet
            if (!hasPhoto)
              Positioned(
                left: -8,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.divider(isDark)),
                  ),
                  child: Text(
                    'OPTIONAL',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Section label
// --------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.isDark, required this.text});
  final bool isDark;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
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

// --------------------------------------------------------------------------
// Styled input field — matches the +91 phone field on login
// --------------------------------------------------------------------------

class _StyledField extends StatefulWidget {
  const _StyledField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.hasError,
    this.keyboardType,
    this.textInputAction,
    this.capitalize,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool hasError;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization? capitalize;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_StyledField> createState() => _StyledFieldState();
}

class _StyledFieldState extends State<_StyledField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final focused = widget.focusNode.hasFocus;
    Color borderColor;
    double borderWidth;
    if (widget.hasError) {
      borderColor = AppColors.warning.withValues(alpha: 0.7);
      borderWidth = 1.4;
    } else if (focused) {
      borderColor = AppColors.tealDark;
      borderWidth = 1.5;
    } else {
      borderColor = AppColors.divider(isDark);
      borderWidth = 1.0;
    }

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              widget.icon,
              size: 18,
              color: focused
                  ? AppColors.tealDark
                  : AppColors.textSecondary(isDark),
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization:
                  widget.capitalize ?? TextCapitalization.none,
              onSubmitted: widget.onSubmitted,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.fromLTRB(0, 16, 14, 16),
                hintText: widget.hint,
                hintStyle: AppTextStyles.body1(isDark).copyWith(
                  color: AppColors.textSecondary(isDark)
                      .withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Continue button — gradient when enabled, muted when not
// --------------------------------------------------------------------------

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.isDark,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool isDark;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: enabled
                  ? LinearGradient(
                      colors: [
                        AppColors.tealDark,
                        AppColors.tealDark.withValues(alpha: 0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: enabled ? null : AppColors.divider(isDark),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.tealDark
                            .withValues(alpha: isDark ? 0.30 : 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue',
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: enabled
                              ? Colors.white
                              : AppColors.textSecondary(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary(isDark),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
