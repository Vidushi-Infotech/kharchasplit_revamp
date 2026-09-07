import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../../../models/models.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/image_processor_service.dart';
import '../../../core/utils/base64_async.dart';
import '../../../data/contacts/device_contacts_provider.dart';
import '../../../data/groups/groups_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../state/groups_provider.dart';
import '../widgets/contacts_picker_sheet.dart';

/// Screen for creating a new group
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  late TextEditingController _groupNameController;
  late TextEditingController _descriptionController;
  late FocusNode _groupNameFocus;
  late FocusNode _descriptionFocus;
  GroupCategory _selectedCategory = GroupCategory.other;
  XFile? _selectedImageFile;
  /// Compressed bytes of the picked cover image. Sent as base64 on submit.
  Uint8List? _coverBytes;
  bool _isProcessing = false;
  bool _isCreating = false;
  bool _isNameValid = false;
  bool _showDescription = false;
  final List<Contact> _selectedContacts = [];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _groupNameFocus = FocusNode();
    _descriptionFocus = FocusNode();
    _groupNameController.addListener(_onNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _groupNameFocus.requestFocus();
      // Pre-warm device contacts in the background. By the time the user
      // taps "Add from contacts" they're already cached.
      ref.read(deviceContactsProvider.future).ignore();
    });
  }

  @override
  void dispose() {
    _groupNameController.removeListener(_onNameChanged);
    _groupNameController.dispose();
    _descriptionController.dispose();
    _groupNameFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final isValid = _groupNameController.text.trim().isNotEmpty;
    if (isValid != _isNameValid) {
      setState(() => _isNameValid = isValid);
    }
  }

  Future<void> _pickContacts() async {
    final selfPhone = ref.read(authProvider).user?.phone ?? '';
    final picked = await showContactsPicker(
      context,
      initialSelected: _selectedContacts,
      selfPhones: selfPhone.isEmpty ? const [] : [selfPhone],
    );
    setState(() {
      _selectedContacts
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      setState(() => _isProcessing = true);

      try {
        final validation =
            await ImageProcessorService.validateImage(pickedFile.path);
        if (!validation.isValid) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Validation failed: ${validation.error}')),
          );
          setState(() => _isProcessing = false);
          return;
        }

        if (!mounted) return;

        final compressedBytes =
            await ImageProcessorService.compressImageToWebP(pickedFile.path);

        // On web/desktop the compressor may return null/empty — fall back to
        // reading the picked file directly so the cover still gets uploaded.
        Uint8List? bytesForUpload =
            (compressedBytes != null && compressedBytes.isNotEmpty)
                ? compressedBytes
                : null;
        bytesForUpload ??= await pickedFile.readAsBytes();

        if (!mounted) return;
        setState(() {
          _selectedImageFile = pickedFile;
          _coverBytes = bytesForUpload;
          _isProcessing = false;
        });
      } catch (processingError, st) {
        AppLogger.error('Image processing error',
            tag: 'create_group', error: processingError, stackTrace: st);
        Uint8List? fallbackBytes;
        try {
          fallbackBytes = await pickedFile.readAsBytes();
        } catch (_) {/* leave null */}
        if (!mounted) return;
        setState(() {
          _selectedImageFile = pickedFile;
          _coverBytes = fallbackBytes;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  Future<void> _createGroup() async {
    // Re-entrancy guard. The sticky button also blocks taps via [enabled],
    // but the flag protects against any other path (Enter key, semantics
    // action, hot reload triggering another tap event).
    if (_isCreating) return;
    setState(() => _isCreating = true);

    final name = _groupNameController.text.trim();
    // Encode the cover off the main isolate — a large cover would otherwise
    // freeze the screen for the duration of the encode.
    final coverBytes = _coverBytes;
    final coverBase64 =
        coverBytes != null ? await base64EncodeAsync(coverBytes) : null;
    if (!mounted) return;
    // 1. Create the group (creator is added as the only member by the backend).
    GroupModel newGroup;
    try {
      newGroup = await ref.read(groupsProvider.notifier).addGroup(
            name: name,
            coverImageBase64: coverBase64,
          );
    } catch (e) {
      if (!mounted) return;
      HapticService.instance.error();
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create group: $e')),
      );
      return;
    }

    // 2. Invite every selected contact via /groups/:id/pending-members.
    //    Backend transparently adds registered users directly and creates a
    //    placeholder + WhatsApp invite for the rest.
    final invitable = _selectedContacts
        .where((c) =>
            c.phones.isNotEmpty && c.phones.first.number.trim().isNotEmpty)
        .toList();
    int succeeded = 0;
    int failed = 0;
    if (invitable.isNotEmpty) {
      final repo = ref.read(groupsRepositoryProvider);
      final results = await Future.wait(
        invitable.map((c) async {
          try {
            await repo.invitePhone(
              groupId: newGroup.id,
              name: c.displayName.isEmpty ? 'Unknown' : c.displayName,
              phoneNumber: c.phones.first.number.trim(),
            );
            return true;
          } catch (_) {
            return false;
          }
        }),
      );
      succeeded = results.where((r) => r).length;
      failed = results.length - succeeded;
      ref.invalidate(groupsProvider);
    }

    // 3. SMTP fallback for emails collected via the contacts picker.
    final emailRecipients = _selectedContacts
        .where((c) =>
            c.emails.isNotEmpty && c.emails.first.address.trim().isNotEmpty)
        .toList();
    int emailSent = 0;
    final emailFailures = <String>[];
    if (emailRecipients.isNotEmpty) {
      final repo = ref.read(groupsRepositoryProvider);
      for (final c in emailRecipients) {
        final addr = c.emails.first.address.trim();
        try {
          await repo.inviteByEmail(
            groupId: newGroup.id,
            email: addr,
            name: c.displayName,
          );
          emailSent++;
        } catch (e) {
          final msg = e is GroupsApiException ? e.message : e.toString();
          emailFailures.add('$addr: $msg');
        }
      }
    }
    final emailFailed = emailFailures.length;

    if (!mounted) return;
    HapticService.instance.success();
    context.go('/home/groups');
    final parts = <String>['Group "$name" created'];
    if (invitable.isNotEmpty) {
      parts.add(failed == 0
          ? '$succeeded member${succeeded == 1 ? '' : 's'} invited'
          : '$succeeded invited, $failed failed');
    }
    if (emailRecipients.isNotEmpty) {
      parts.add(emailFailed == 0
          ? '$emailSent email${emailSent == 1 ? '' : 's'} sent'
          : '$emailSent email${emailSent == 1 ? '' : 's'} sent, $emailFailed failed');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.join(' · '))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final double maxFormWidth = screenWidth < 600
        ? double.infinity
        : screenWidth < 1100
            ? 600
            : 700;
    final double horizontalPad = screenWidth < 600
        ? 16
        : screenWidth < 1100
            ? 24
            : 32;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        title: 'Create group',
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  horizontalPad,
                  horizontalPad,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxFormWidth),
                    child: _buildFormBody(isDark),
                  ),
                ),
              ),
            ),
            _StickyCreateBar(
              isDark: isDark,
              enabled: _isNameValid && !_isCreating,
              loading: _isCreating,
              horizontalPad: horizontalPad,
              maxFormWidth: maxFormWidth,
              onTap: _createGroup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormBody(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCoverAndNameRow(isDark),
        const SizedBox(height: 28),
        _SectionTitle(label: 'Category', isDark: isDark),
        const SizedBox(height: 10),
        _buildCategorySelector(isDark),
        const SizedBox(height: 28),
        _SectionTitle(
          label: 'Members',
          isDark: isDark,
          trailing: _selectedContacts.isEmpty
              ? null
              : Text(
                  '${_selectedContacts.length}',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        _buildMembersSection(isDark),
        const SizedBox(height: 24),
        _buildDescriptionToggle(isDark),
      ],
    );
  }

  Widget _buildCoverAndNameRow(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCircularCover(isDark),
        const SizedBox(width: 14),
        Expanded(
          child: AppTextField(
            controller: _groupNameController,
            focusNode: _groupNameFocus,
            hint: 'e.g., Goa Trip',
            label: 'Group name',
          ),
        ),
      ],
    );
  }

  Widget _buildCircularCover(bool isDark) {
    const size = 72.0;
    Widget content;
    if (_isProcessing) {
      content = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.tealDark),
        ),
      );
    } else if (_selectedImageFile != null) {
      content = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: kIsWeb
              ? Image.network(_selectedImageFile!.path, fit: BoxFit.cover)
              : Image.file(File(_selectedImageFile!.path), fit: BoxFit.cover),
        ),
      );
    } else {
      content = Icon(
        Icons.add_a_photo_outlined,
        size: 24,
        color: AppColors.tealDark,
      );
    }

    return Semantics(
      button: true,
      label: _selectedImageFile == null
          ? 'Add cover image'
          : 'Change cover image',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isProcessing ? null : _pickImage,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _selectedImageFile == null
                  ? AppColors.tealDark.withValues(alpha: 0.10)
                  : AppColors.cardBg(isDark),
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedImageFile == null
                    ? AppColors.tealDark.withValues(alpha: 0.35)
                    : AppColors.divider(isDark),
                width: _selectedImageFile == null ? 1.5 : 1,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: GroupCategory.values.map((category) {
        final isSelected = category == _selectedCategory;
        final name = _categoryLabel(category);
        final emoji = _categoryEmoji(category);

        return Semantics(
          button: true,
          label: 'Category $name',
          selected: isSelected,
          child: GestureDetector(
            onTap: () {
              if (_selectedCategory != category) {
                HapticService.instance.selection();
              }
              setState(() => _selectedCategory = category);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.tealDark
                    : AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? AppColors.tealDark
                      : AppColors.divider(isDark),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary(isDark),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _categoryEmoji(GroupCategory c) {
    switch (c) {
      case GroupCategory.trip:
        return '✈️';
      case GroupCategory.home:
        return '🏠';
      case GroupCategory.couple:
        return '💑';
      case GroupCategory.work:
        return '💼';
      case GroupCategory.other:
        return '🏷️';
    }
  }

  String _categoryLabel(GroupCategory c) {
    final s = c.toString().split('.').last;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildMembersSection(bool isDark) {
    if (_selectedContacts.isEmpty) {
      return Semantics(
        button: true,
        label: 'Add members from contacts',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickContacts,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.tealDark.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tealDark.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 18,
                      color: AppColors.tealDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add members',
                          style: AppTextStyles.body1(isDark).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.tealDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick from your contacts',
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.tealDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          _AvatarStack(
            contacts: _selectedContacts,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _membersPreviewText(),
              style: AppTextStyles.body2(isDark).copyWith(
                fontSize: 13,
                color: AppColors.textPrimary(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _PillButton(
            icon: Icons.edit_rounded,
            label: 'Edit',
            isDark: isDark,
            onTap: _pickContacts,
          ),
        ],
      ),
    );
  }

  String _membersPreviewText() {
    final names = _selectedContacts
        .map((c) => c.displayName.isEmpty ? 'Unknown' : c.displayName)
        .toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  Widget _buildDescriptionToggle(bool isDark) {
    if (!_showDescription) {
      return Semantics(
        button: true,
        label: 'Add notes',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _showDescription = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _descriptionFocus.requestFocus();
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppColors.tealDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add notes (optional)',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: 'Group description input',
      child: AppTextField(
        controller: _descriptionController,
        focusNode: _descriptionFocus,
        hint: 'Add notes about this group…',
        label: 'Notes',
        maxLines: 3,
      ),
    );
  }
}

/// Top bar matching the rest of the app — back arrow + bold title.
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.isDark,
    this.trailing,
  });

  final String label;
  final bool isDark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textPrimary(isDark),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.1,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Bottom-anchored Create button. Disabled (greyed) until the name is
/// non-empty; on tap fires [onTap].
class _StickyCreateBar extends StatelessWidget {
  const _StickyCreateBar({
    required this.isDark,
    required this.enabled,
    required this.loading,
    required this.horizontalPad,
    required this.maxFormWidth,
    required this.onTap,
  });

  final bool isDark;
  final bool enabled;
  final bool loading;
  final double horizontalPad;
  final double maxFormWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.divider(isDark).withValues(alpha: 0.7),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            10,
            horizontalPad,
            10,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxFormWidth),
              child: Semantics(
                button: true,
                enabled: enabled,
                label: 'Create group',
                child: Opacity(
                  opacity: (enabled || loading) ? 1 : 0.45,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: enabled ? onTap : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.tealLight,
                              AppColors.tealDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: (enabled || loading)
                              ? [
                                  BoxShadow(
                                    color: AppColors.tealDark
                                        .withValues(alpha: 0.30),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (loading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            else
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              loading ? 'Creating…' : 'Create group',
                              style: AppTextStyles.body1(isDark).copyWith(
                                color: Colors.white,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar stack — first few members shown as overlapping initial circles.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.contacts, required this.isDark});

  final List<Contact> contacts;
  final bool isDark;

  static const _palette = <Color>[
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFF7E57C2),
    Color(0xFFEF5350),
  ];

  @override
  Widget build(BuildContext context) {
    const maxAvatars = 3;
    final shown = contacts.take(maxAvatars).toList();
    final extra = contacts.length - shown.length;
    final tileCount = shown.length + (extra > 0 ? 1 : 0);

    const tile = 30.0;
    const overlap = 22.0;
    final width = tile + overlap * (tileCount - 1);

    return SizedBox(
      width: width.clamp(tile, 200).toDouble(),
      height: tile,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * overlap,
              child: _initialAvatar(shown[i], i, isDark),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * overlap,
              child: _moreBadge(extra, isDark),
            ),
        ],
      ),
    );
  }

  Widget _initialAvatar(Contact c, int i, bool isDark) {
    final name = c.displayName.isEmpty ? '?' : c.displayName;
    final initial = name.characters.first.toUpperCase();
    final color = _palette[i % _palette.length];
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: AppColors.background(isDark),
          width: 2,
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _moreBadge(int extra, bool isDark) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface(isDark),
        border: Border.all(
          color: AppColors.background(isDark),
          width: 2,
        ),
      ),
      child: Text(
        '+$extra',
        style: AppTextStyles.caption(isDark).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.textPrimary(isDark),
        ),
      ),
    );
  }
}

/// Small pill-shaped button used inside cards.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.tealDark.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.tealDark),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
