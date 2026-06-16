import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/image_processor_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../state/groups_provider.dart';
import 'group_cover_thumb.dart';

/// Bottom sheet for editing a group's name, description, and cover photo.
/// Admin-only — the caller is responsible for showing it only when the
/// current user owns the group (backend also rejects non-admin writes).
///
/// Returns the updated [GroupModel] on save, or null if the user dismissed.
class EditGroupSheet extends ConsumerStatefulWidget {
  const EditGroupSheet({super.key, required this.group});

  final GroupModel group;

  /// Shows the sheet and returns the updated group (or null on cancel).
  static Future<GroupModel?> show(
    BuildContext context, {
    required GroupModel group,
  }) {
    return showModalBottomSheet<GroupModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => EditGroupSheet(group: group),
    );
  }

  @override
  ConsumerState<EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<EditGroupSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();

  /// Newly-picked photo bytes (overrides the existing cover when set).
  Uint8List? _newCoverBytes;

  /// True when the user explicitly removed the existing photo.
  bool _coverRemoved = false;

  bool _picking = false;
  bool _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descController = TextEditingController();
    _nameController.addListener(() {
      if (_nameError != null && mounted) setState(() => _nameError = null);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _nameFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_nameController.text.trim() != widget.group.name) return true;
    if (_newCoverBytes != null) return true;
    if (_coverRemoved && widget.group.coverImageBase64 != null) return true;
    return false;
  }

  bool get _isValid {
    final n = _nameController.text.trim();
    return n.length >= 2;
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      // Same compression pipeline as create flow.
      Uint8List? bytes =
          await ImageProcessorService.compressImageToWebP(picked.path);
      if (bytes == null || bytes.isEmpty) {
        bytes = await picked.readAsBytes();
      }
      if (!mounted) return;
      setState(() {
        _newCoverBytes = bytes;
        _coverRemoved = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePhoto() {
    setState(() {
      _newCoverBytes = null;
      _coverRemoved = true;
    });
  }

  Future<void> _save() async {
    if (!_isValid) {
      setState(() => _nameError =
          _nameController.text.trim().isEmpty
              ? 'Group name is required'
              : 'Name is too short');
      return;
    }
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    final newName = _nameController.text.trim();
    String? coverPayload;
    if (_newCoverBytes != null) {
      coverPayload = base64Encode(_newCoverBytes!);
    } else if (_coverRemoved) {
      // Empty string clears the cover; backend stores null when COALESCE
      // sees a falsy value (the controller treats empty string the same
      // as not-sent, so explicit clearing requires a small workaround).
      coverPayload = '';
    }

    try {
      final updated = await ref.read(groupsProvider.notifier).updateGroup(
            widget.group.id,
            name: newName != widget.group.name ? newName : null,
            coverImageBase64: coverPayload,
          );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update group: $e')),
      );
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
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Handle(isDark: isDark),
              _Header(isDark: isDark, onClose: () => Navigator.of(context).pop()),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: _CoverPicker(
                          isDark: isDark,
                          existingBase64: widget.group.coverImageBase64,
                          existingEmoji: widget.group.coverEmoji,
                          newBytes: _newCoverBytes,
                          removed: _coverRemoved,
                          picking: _picking,
                          onPick: _pickPhoto,
                          onRemove:
                              (widget.group.coverImageBase64 != null ||
                                      _newCoverBytes != null)
                                  ? _removePhoto
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel(isDark: isDark, text: 'GROUP NAME'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        hint: 'e.g. Goa Trip 2026',
                        icon: Icons.group_outlined,
                        isDark: isDark,
                        hasError: _nameError != null,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_isValid && _hasChanges && !_saving) _save();
                        },
                      ),
                      if (_nameError != null)
                        _FieldError(text: _nameError!, isDark: isDark),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _GhostButton(
                              isDark: isDark,
                              label: 'Cancel',
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PrimaryButton(
                              isDark: isDark,
                              label: 'Save',
                              enabled: _isValid && _hasChanges && !_saving,
                              loading: _saving,
                              onPressed: _save,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Subwidgets
// --------------------------------------------------------------------------

class _Handle extends StatelessWidget {
  const _Handle({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider(isDark),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onClose});
  final bool isDark;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit group',
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Only the admin can update these details.',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary(isDark),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

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

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.isDark,
    required this.existingBase64,
    required this.existingEmoji,
    required this.newBytes,
    required this.removed,
    required this.picking,
    required this.onPick,
    required this.onRemove,
  });

  final bool isDark;
  final String? existingBase64;
  final String existingEmoji;
  final Uint8List? newBytes;
  final bool removed;
  final bool picking;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasNew = newBytes != null;
    final showExisting = !removed && !hasNew && existingBase64 != null;

    Widget cover;
    if (hasNew) {
      cover = ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.memory(
          newBytes!,
          width: 116,
          height: 116,
          fit: BoxFit.cover,
        ),
      );
    } else if (showExisting) {
      cover = GroupCoverThumb(
        coverImageBase64: existingBase64,
        coverEmoji: existingEmoji,
        size: 116,
        borderRadius: 28,
      );
    } else {
      cover = Container(
        width: 116,
        height: 116,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.divider(isDark), width: 1.5),
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          size: 28,
          color: AppColors.tealDark,
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: picking ? null : onPick,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Soft halo
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealDark
                      .withValues(alpha: isDark ? 0.10 : 0.06),
                ),
              ),
              cover,
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
                      : const Icon(
                          Icons.edit_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
        if (onRemove != null && !removed) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onRemove,
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

class _StyledField extends StatefulWidget {
  const _StyledField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.hasError,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool hasError;
  final TextInputAction? textInputAction;
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
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(0, 16, 14, 16),
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
          Icon(Icons.error_outline_rounded, size: 14, color: AppColors.warning),
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

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.isDark,
    required this.label,
    required this.onPressed,
  });

  final bool isDark;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Text(
              label,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.isDark,
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool isDark;
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
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
                            .withValues(alpha: isDark ? 0.30 : 0.20),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: enabled
                              ? Colors.white
                              : AppColors.textSecondary(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_rounded,
                        size: 17,
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
