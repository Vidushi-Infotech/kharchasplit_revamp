import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';

/// Avatar picker widget with circular display
/// Tap to show bottom sheet with Camera/Gallery options
/// Displays gradient placeholder if no image selected
class AvatarPickerWidget extends StatefulWidget {
  final Function(File) onImageSelected;
  final File? selectedImage;
  final double size;

  const AvatarPickerWidget({
    Key? key,
    required this.onImageSelected,
    this.selectedImage,
    this.size = 120,
  }) : super(key: key);

  @override
  State<AvatarPickerWidget> createState() => _AvatarPickerWidgetState();
}

class _AvatarPickerWidgetState extends State<AvatarPickerWidget> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        widget.onImageSelected(File(pickedFile.path));
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showPickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Text(
              'Select Profile Picture',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            // Camera option
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a Photo'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            // Gallery option
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _showPickerSheet,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.tealDark,
              AppColors.greenLight,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealDark.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.selectedImage != null
            ? ClipOval(
                child: Image.file(
                  widget.selectedImage!,
                  fit: BoxFit.cover,
                ),
              )
            : Center(
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: widget.size * 0.4,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
