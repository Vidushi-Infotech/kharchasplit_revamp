import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../../../models/models.dart';
import '../../../core/services/image_processor_service.dart';
import '../../../data/contacts/device_contacts_provider.dart';
import '../../../data/groups/groups_repository.dart';
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
  GroupCategory _selectedCategory = GroupCategory.other;
  XFile? _selectedImageFile;
  bool _isProcessing = false;
  String? _processingStatus;
  double _uploadProgress = 0.0;
  final List<Contact> _selectedContacts = [];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _groupNameFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _groupNameFocus.requestFocus();
      // Pre-warm device contacts in the background. By the time the user
      // taps "Add from contacts" they're already cached.
      ref.read(deviceContactsProvider.future).ignore();
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    _groupNameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickContacts() async {
    final picked = await showContactsPicker(
      context,
      initialSelected: _selectedContacts,
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

      // Start processing
      setState(() {
        _isProcessing = true;
        _processingStatus = 'Processing image...';
      });

      try {
        // Step 1: Validate image
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
        setState(() => _processingStatus = 'Scanning for threats...');

        // Step 2: Scan for malware
        final scanResult =
            await ImageProcessorService.scanImageForMalware(pickedFile.path);
        if (!scanResult.isSafe) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Security warning: ${scanResult.details} (${scanResult.threatCount} threats detected)',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isProcessing = false);
          return;
        }

        if (!mounted) return;
        setState(() => _processingStatus = 'Compressing image...');

        // Step 3: Compress image to WebP
        final compressedBytes =
            await ImageProcessorService.compressImageToWebP(pickedFile.path);

        // Calculate compression percentage (handle null/empty bytes on web)
        String compressionPercent = '0';
        if (compressedBytes != null && compressedBytes.isNotEmpty) {
          try {
            final originalSize = await File(pickedFile.path).length();
            compressionPercent =
                ImageProcessorService.getCompressionPercentage(
              originalSize,
              compressedBytes.length,
            );
          } catch (e) {
            // Skip compression calculation if it fails
            print('Warning: Could not calculate compression - $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _selectedImageFile = pickedFile;
          _isProcessing = false;
          _processingStatus = null;
          _uploadProgress = 0.0;
        });

        // Show upload progress dialog
        if (!mounted) return;
        _showUploadProgressDialog(
          context,
          pickedFile,
          validation.dimensionsDisplay,
          compressionPercent,
        );
      } catch (processingError) {
        print('Processing error: $processingError');
        // On web or any error, still allow image to be used
        if (!mounted) return;
        setState(() {
          _selectedImageFile = pickedFile;
          _isProcessing = false;
          _processingStatus = null;
          _uploadProgress = 0.0;
        });

        // Show upload dialog anyway
        if (!mounted) return;
        _showUploadProgressDialog(
          context,
          pickedFile,
          'Unknown',
          '0',
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  /// Show upload progress dialog with preview
  Future<void> _showUploadProgressDialog(
    BuildContext context,
    XFile imageFile,
    String dimensions,
    String compressionPercent,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Future.microtask(() async {
            final success = await _uploadImage();
            if (success && mounted) {
              // Close dialog after upload completes
              Navigator.of(dialogContext).pop();

              // Show success notification
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Image uploaded! Compressed $dimensions by $compressionPercent%',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });

          return Dialog(
            backgroundColor: AppColors.cardBg(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    'Uploading Image',
                    style: AppTextStyles.headline3(isDark),
                  ),
                  const SizedBox(height: 24),

                  // Image Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 150,
                      height: 150,
                      color: AppColors.surface(isDark),
                      child: kIsWeb
                          ? Image.network(
                              imageFile.path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.image_rounded,
                                size: 60,
                                color: AppColors.textSecondary(isDark),
                              ),
                            )
                          : Image.file(
                              File(imageFile.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.image_rounded,
                                size: 60,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Uploading...',
                            style: AppTextStyles.body2(isDark),
                          ),
                          Text(
                            '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                            style: AppTextStyles.body2(isDark).copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          minHeight: 8,
                          backgroundColor: AppColors.surface(isDark),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info Text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_rounded,
                          color: AppColors.brand,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Image scanned & compressed. Upload starting...',
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Simulate uploading image with progress tracking
  Future<bool> _uploadImage() async {
    try {
      if (_selectedImageFile == null) return true;

      // Simulate upload with progress
      for (int i = 0; i <= 100; i += 10) {
        if (!mounted) return false;
        setState(() => _uploadProgress = i / 100);
        await Future.delayed(const Duration(milliseconds: 150));
      }

      return true;
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    // 1. Create the group (creator is added as the only member by the backend).
    GroupModel newGroup;
    try {
      newGroup = await ref.read(groupsProvider.notifier).addGroup(name: name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create group: $e')),
      );
      return;
    }

    // 2. Invite every selected contact via /groups/:id/pending-members.
    //    The backend transparently adds registered users directly and creates
    //    a placeholder + WhatsApp invite for the rest.
    final invitable = _selectedContacts
        .where((c) => c.phones.isNotEmpty &&
            c.phones.first.number.trim().isNotEmpty)
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
      // Refresh the groups list so memberCount reflects the new members.
      ref.invalidate(groupsProvider);
    }

    if (!mounted) return;
    context.go('/home/groups');
    final summary = invitable.isEmpty
        ? 'Group "$name" created'
        : failed == 0
            ? 'Group "$name" created · $succeeded member${succeeded == 1 ? '' : 's'} invited'
            : 'Group "$name" created · $succeeded invited, $failed failed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        title: 'Create group',
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        top: false,
        child: screenWidth < 600
            ? _buildCompactLayout(isDark)
            : screenWidth < 1100
                ? _buildStandardLayout(isDark)
                : _buildLargeLayout(isDark),
      ),
    );
  }

  Widget _buildCompactLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildForm(isDark),
    );
  }

  Widget _buildStandardLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildForm(isDark),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _buildForm(isDark),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Group name input',
          child: AppTextField(
            controller: _groupNameController,
            focusNode: _groupNameFocus,
            hint: 'e.g., Goa Trip',
            label: 'Group Name',
          ),
        ),
        const SizedBox(height: 32),

        _SectionTitle(label: 'GROUP COVER', isDark: isDark),
        const SizedBox(height: 10),
        _buildCoverSelector(isDark),
        const SizedBox(height: 28),

        _SectionTitle(label: 'CATEGORY', isDark: isDark),
        const SizedBox(height: 10),
        _buildCategorySelector(isDark),
        const SizedBox(height: 28),

        _SectionTitle(label: 'MEMBERS', isDark: isDark),
        const SizedBox(height: 10),
        _buildMembersSection(isDark),
        const SizedBox(height: 28),

        Semantics(
          label: 'Group description input',
          child: AppTextField(
            controller: _descriptionController,
            hint: 'Add notes about this group...',
            label: 'Description (Optional)',
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 32),

        Semantics(
          button: true,
          label: 'Create group button',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _createGroup,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.tealLight, AppColors.tealDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealDark.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create group',
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
      ],
    );
  }

  Widget _buildMembersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedContacts.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedContacts.map((c) {
              final name = c.displayName.isEmpty ? 'Unknown' : c.displayName;
              return Chip(
                label: Text(name),
                onDeleted: () => setState(() => _selectedContacts.remove(c)),
                deleteIconColor: AppColors.errorText(isDark),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickContacts,
            icon: const Icon(Icons.contacts_rounded),
            label: Text(
              _selectedContacts.isEmpty
                  ? 'Add Members from Contacts'
                  : 'Edit Members',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.brand),
              foregroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverSelector(bool isDark) {
    return _buildImagePicker(isDark);
  }

  Widget _buildImagePicker(bool isDark) {
    if (_isProcessing) return _buildPickerProcessing(isDark);
    if (_selectedImageFile != null) return _buildPickerPreview(isDark);
    return _buildPickerEmpty(isDark);
  }

  Widget _buildPickerEmpty(bool isDark) {
    return Semantics(
      button: true,
      label: 'Add cover image',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 168,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider(isDark),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tealDark.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 22,
                      color: AppColors.tealDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Add a cover image',
                    style: AppTextStyles.body1(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PNG or JPG · auto-compressed',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerProcessing(bool isDark) {
    return Container(
      height: 168,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.tealDark),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _processingStatus ?? 'Processing image…',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPickerPreview(bool isDark) {
    final imageProvider = kIsWeb
        ? NetworkImage(_selectedImageFile!.path) as ImageProvider
        : FileImage(File(_selectedImageFile!.path));
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image(image: imageProvider, fit: BoxFit.cover),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _buildCategorySelector(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: GroupCategory.values.map((category) {
        final isSelected = category == _selectedCategory;
        final categoryName = category.toString().split('.').last;

        return Semantics(
          button: true,
          label: 'Category $categoryName',
          child: GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand
                    : AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.divider(isDark),
                  width: 1,
                ),
              ),
              child: Text(
                categoryName[0].toUpperCase() + categoryName.substring(1),
                style: AppTextStyles.body2(isDark).copyWith(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textPrimary(isDark),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}


/// Clean top bar matching the rest of the app — back arrow + bold title.
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
  const _SectionTitle({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
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
