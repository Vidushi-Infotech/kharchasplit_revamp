import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class InvoiceUploadWidget extends StatefulWidget {
  final Function(String, File) onImageSelected;
  final VoidCallback onProcessing;
  final VoidCallback onComplete;
  final bool isLoading;

  const InvoiceUploadWidget({
    Key? key,
    required this.onImageSelected,
    required this.onProcessing,
    required this.onComplete,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<InvoiceUploadWidget> createState() => _InvoiceUploadWidgetState();
}

class _InvoiceUploadWidgetState extends State<InvoiceUploadWidget> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() => _selectedImage = file);
        widget.onImageSelected(pickedFile.path, file);
        widget.onProcessing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invoice/Receipt (Optional)',
          style: AppTextStyles.body2(isDark),
        ),
        const SizedBox(height: 12),
        if (_selectedImage != null)
          _buildImagePreview(isDark, isCompact)
        else
          _buildUploadOptions(isDark, isCompact),
      ],
    );
  }

  Widget _buildImagePreview(bool isDark, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider(isDark),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.file(
              _selectedImage!,
              height: isCompact ? 200 : 250,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.isLoading)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.successLight(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Scanning invoice...',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () => setState(() => _selectedImage = null),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.warning),
              ),
              child: const Text('Remove Image'),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadOptions(bool isDark, bool isCompact) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildUploadButton(
                isDark,
                Icons.camera_alt_rounded,
                'Capture',
                () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildUploadButton(
                isDark,
                Icons.image_rounded,
                'Gallery',
                () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warningLight(isDark),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.warning.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload invoice to auto-detect amount, category & date',
                  style: AppTextStyles.caption(isDark).copyWith(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton(
    bool isDark,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppColors.brand,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
