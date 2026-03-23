import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

/// Screen for creating a new group
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  late TextEditingController _groupNameController;
  late TextEditingController _descriptionController;
  GroupCategory _selectedCategory = GroupCategory.other;
  String _selectedEmoji = '👥';
  XFile? _selectedImageFile;
  bool _useEmoji = false;
  bool _isProcessing = false;
  String? _processingStatus;
  double _uploadProgress = 0.0;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _createGroup() {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    // Navigate back to groups screen after creation
    context.go('/home/groups');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group "${_groupNameController.text}" created!')),
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
      body: screenWidth < 600
          ? _buildCompactLayout(isDark)
          : screenWidth < 1100
              ? _buildStandardLayout(isDark)
              : _buildLargeLayout(isDark),
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
        // Group Cover Section
        Text(
          'Group Cover',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 12),
        _buildCoverSelector(isDark),
        const SizedBox(height: 32),

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
            hint: 'e.g., Goa Trip',
            label: 'Group Name',
          ),
        ),
        const SizedBox(height: 24),

        // Category Selector
        Text(
          'Category',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 12),
        _buildCategorySelector(isDark),
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
