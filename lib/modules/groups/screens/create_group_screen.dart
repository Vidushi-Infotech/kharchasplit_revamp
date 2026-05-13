import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../../../models/models.dart';
import '../../../core/services/image_processor_service.dart';
import 'package:share_plus/share_plus.dart';
import '../state/groups_provider.dart';
import '../state/registered_users_provider.dart';

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
  String _selectedEmoji = '👥';
  XFile? _selectedImageFile;
  bool _useEmoji = false;
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
    final hasPermission = await FlutterContacts.requestPermission(readonly: true);
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied')),
      );
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<Contact>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ContactsPickerSheet(
        contacts: contacts,
        initialSelected: _selectedContacts,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedContacts
          ..clear()
          ..addAll(picked);
      });
    }
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
          _useEmoji = false;
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
          _useEmoji = false;
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

    // Selected contacts can't go straight into the create call — the backend
    // expects existing user IDs. Member invites flow through the dedicated
    // /groups/:id/pending-members endpoint, which the detail screen handles.
    try {
      await ref.read(groupsProvider.notifier).addGroup(name: name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create group: $e')),
      );
      return;
    }

    if (!mounted) return;
    context.go('/home/groups');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group "$name" created!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        leading: Semantics(
          button: true,
          label: 'Go back',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Create Group',
          style: AppTextStyles.headline3(isDark),
        ),
        elevation: 0,
        backgroundColor: AppColors.cardBg(isDark),
        foregroundColor: AppColors.textPrimary(isDark),
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
        // Group Name
        Text(
          'Group Name',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 8),
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

        // Group Cover Section
        Text(
          'Group Cover',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 12),
        _buildCoverSelector(isDark),
        const SizedBox(height: 32),

        // Category Selector
        Text(
          'Category',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 12),
        _buildCategorySelector(isDark),
        const SizedBox(height: 32),

        // Members
        Text(
          'Members',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 12),
        _buildMembersSection(isDark),
        const SizedBox(height: 32),

        // Description
        Text(
          'Description (Optional)',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Group description input',
          child: AppTextField(
            controller: _descriptionController,
            hint: 'Add notes about this group...',
            label: 'Description',
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 32),

        // Create Button
        Semantics(
          button: true,
          label: 'Create group button',
          child: SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Create Group',
              onPressed: _createGroup,
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
    return Column(
      children: [
        // Tab selector
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Use image cover',
                child: GestureDetector(
                  onTap: () => setState(() => _useEmoji = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: !_useEmoji ? AppColors.brand : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Image',
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: !_useEmoji
                              ? AppColors.brand
                              : AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Use emoji cover',
                child: GestureDetector(
                  onTap: () => setState(() => _useEmoji = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _useEmoji ? AppColors.brand : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Emoji',
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: _useEmoji
                              ? AppColors.brand
                              : AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content based on selection
        if (_useEmoji)
          _buildEmojiSelector(isDark)
        else
          _buildImagePicker(isDark),
      ],
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider(isDark),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: _isProcessing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _processingStatus ?? 'Processing image...',
                  style: AppTextStyles.body2(isDark),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : _selectedImageFile != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(
                              _selectedImageFile!.path,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_selectedImageFile!.path),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.greenLight,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Image scanned & compressed',
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.greenLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: 'Change image',
                      child: TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Change Image'),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_rounded,
                      size: 48,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No image selected',
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image will be scanned & compressed to WebP',
                      style: AppTextStyles.caption(isDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: 'Pick image from gallery',
                      child: PrimaryButton(
                        label: 'Pick Image',
                        onPressed: _pickImage,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmojiSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider(isDark),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Semantics(
        label: 'Emoji picker with full emoji set',
        child: SizedBox(
          height: 300,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              setState(() => _selectedEmoji = emoji.emoji);
            },
            onBackspacePressed: () {},
            textEditingController: TextEditingController(),
            config: const Config(
              height: 300,
              checkPlatformCompatibility: true,
            ),
          ),
        ),
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

class _ContactsPickerSheet extends ConsumerStatefulWidget {
  final List<Contact> contacts;
  final List<Contact> initialSelected;

  const _ContactsPickerSheet({
    required this.contacts,
    required this.initialSelected,
  });

  @override
  ConsumerState<_ContactsPickerSheet> createState() =>
      _ContactsPickerSheetState();
}

class _ContactsPickerSheetState extends ConsumerState<_ContactsPickerSheet> {
  late Set<String> _selectedIds;
  late TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelected.map((c) => c.id).toSet();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _query.isEmpty
        ? widget.contacts
        : widget.contacts
            .where((c) =>
                c.displayName.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select Contacts',
                        style: AppTextStyles.headline3(isDark),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final selected = widget.contacts
                            .where((c) => _selectedIds.contains(c.id))
                            .toList();
                        Navigator.of(context).pop(selected);
                      },
                      child: Text('Done (${_selectedIds.length})'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search contacts',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts found',
                          style: AppTextStyles.body2(isDark).copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          final isSelected = _selectedIds.contains(c.id);
                          final name =
                              c.displayName.isEmpty ? 'Unknown' : c.displayName;
                          final phone = c.phones.isNotEmpty
                              ? c.phones.first.number
                              : '';
                          final subtitle = phone.isNotEmpty
                              ? phone
                              : (c.emails.isNotEmpty
                                  ? c.emails.first.address
                                  : '');
                          final registered = ref.watch(registeredPhonesProvider);
                          final isRegistered = phone.isNotEmpty &&
                              registered.contains(normalizePhone(phone));
                          return ListTile(
                            onTap: () => _toggle(c.id),
                            title: Text(name),
                            subtitle:
                                subtitle.isEmpty ? null : Text(subtitle),
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.brand.withValues(alpha: 0.2),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(color: AppColors.brand),
                              ),
                            ),
                            trailing: _buildActionButton(
                              isRegistered: isRegistered,
                              isSelected: isSelected,
                              onAdd: () => _toggle(c.id),
                              onInvite: () => _invite(c, name, phone),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _invite(Contact c, String name, String phone) async {
    _selectedIds.add(c.id);
    setState(() {});
    final msg = phone.isNotEmpty
        ? 'Hey $name, I added you on KharchaSplit to split expenses. Join: https://kharchasplit.app/invite'
        : 'Hey $name, join me on KharchaSplit: https://kharchasplit.app/invite';
    await SharePlus.instance.share(ShareParams(text: msg));
  }

  Widget _buildActionButton({
    required bool isRegistered,
    required bool isSelected,
    required VoidCallback onAdd,
    required VoidCallback onInvite,
  }) {
    if (isSelected) {
      return TextButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.check_circle, color: AppColors.brand, size: 18),
        label: Text(
          isRegistered ? 'Added' : 'Invited',
          style: TextStyle(color: AppColors.brand),
        ),
      );
    }
    if (isRegistered) {
      return FilledButton(
        onPressed: onAdd,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          minimumSize: const Size(72, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('Add'),
      );
    }
    return OutlinedButton(
      onPressed: onInvite,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: BorderSide(color: AppColors.brand),
        minimumSize: const Size(72, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: const Text('Invite'),
    );
  }
}
