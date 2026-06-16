import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class InvoiceUploadWidget extends StatefulWidget {
  final Function(String, File) onImageSelected;

  const InvoiceUploadWidget({
    Key? key,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  State<InvoiceUploadWidget> createState() => _InvoiceUploadWidgetState();
}

class _InvoiceUploadWidgetState extends State<InvoiceUploadWidget> {
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Compress at capture time — receipts only need legibility, not full
      // sensor resolution. Keeps the base64 payload well under the backend's
      // request-body limit.
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1600,
      );
      if (pickedFile != null) {
        // For web, read image as bytes; for mobile, use File
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _imagePath = pickedFile.path;
          });
        } else {
          final file = File(pickedFile.path);
          setState(() {
            _selectedImage = file;
            _imagePath = pickedFile.path;
          });
        }
        widget.onImageSelected(pickedFile.path, File(pickedFile.path));
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;

    final hasImage = kIsWeb ? _selectedImageBytes != null : _selectedImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt (Optional)',
          style: AppTextStyles.body2(isDark),
        ),
        const SizedBox(height: 12),
        if (hasImage)
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
            child: kIsWeb
                ? Image.memory(
                    _selectedImageBytes!,
                    height: isCompact ? 200 : 250,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    _selectedImage!,
                    height: isCompact ? 200 : 250,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _selectedImage = null;
              _selectedImageBytes = null;
              _imagePath = null;
            }),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.warning),
            ),
            child: const Text('Remove image'),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadOptions(bool isDark, bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.brand,
          strokeWidth: 2,
          dashWidth: 8,
          dashSpace: 4,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Semantics(
                      button: true,
                      label: 'Take photo',
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: AppColors.brand,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Capture',
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Semantics(
                      button: true,
                      label: 'Pick from gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Column(
                        children: [
                          Icon(
                            Icons.image_rounded,
                            color: AppColors.brand,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gallery',
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Attach a photo of the bill as proof',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

/// Custom painter for dashed border
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    const radius = 12.0;

    // Create rounded rectangle path
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(radius),
      ),
    );

    // Draw dashed path
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (var metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}
