import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import 'app_logger.dart';

/// Compression + format-validation utilities for receipt / cover images.
///
/// Note: an earlier version of this service called the VirusTotal API to
/// scan uploaded images, but the implementation only ever shipped with a
/// `YOUR_VIRUSTOTAL_API_KEY` placeholder and no real key. That dead code
/// was removed; if image scanning is reintroduced it should live behind a
/// server-side proxy so the API key never lands on a user's device.
/// Isolate entry point for [ImageProcessorService.validateImage]. Returns a
/// small record rather than the decoded [img.Image] so only two ints cross
/// the isolate boundary.
({int width, int height})? _readDimensions(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return (width: image.width, height: image.height);
}

class ImageProcessorService {

  /// Compress image to WebP format with quality optimization
  /// On web: Returns empty bytes (browser already optimizes)
  /// On mobile: Returns WebP compressed bytes
  static Future<Uint8List?> compressImageToWebP(
    String imagePath, {
    int quality = 80,
  }) async {
    try {
      // On web, images are already optimized by the browser
      // Modern browsers (Chrome, Firefox, Edge) automatically compress images
      // We simply accept them as-is for efficiency
      if (kIsWeb) {
        AppLogger.info(
            'Web mode: Using browser-optimized image (native JPEG/PNG compression)',
            tag: 'image');
        return Uint8List(0); // Return empty to indicate web mode success
      }

      // On mobile: Compress to WebP format
      final File imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      AppLogger.info(
          'Mobile mode: Compressing image to WebP format (quality: $quality%)',
          tag: 'image');

      // Compress and convert to WebP
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 1920,
        minWidth: 1080,
        quality: quality,
        format: CompressFormat.webp,
      );

      return compressedBytes;
    } catch (e, st) {
      AppLogger.error('Error compressing image',
          tag: 'image', error: e, stackTrace: st);
      // Return empty bytes to allow upload to continue
      return Uint8List(0);
    }
  }

  /// Scan image for malware using VirusTotal API
  /// On web: Browser handles file validation through file picker
  /// Validate image file
  /// Checks file size, format, and basic properties
  static Future<ValidationResult> validateImage(String imagePath) async {
    try {
      // On web, minimal validation (browser already validated file)
      if (kIsWeb) {
        return ValidationResult(
          isValid: true,
          fileSize: null,
          width: null,
          height: null,
        );
      }

      final bytes = await _getImageBytes(imagePath);
      if (bytes == null || bytes.isEmpty) {
        return ValidationResult(
          isValid: false,
          error: 'Could not read image file',
        );
      }

      // Check file size (max 50MB)
      const maxSize = 50 * 1024 * 1024; // 50MB
      if (bytes.length > maxSize) {
        return ValidationResult(
          isValid: false,
          error: 'Image too large (max 50MB)',
        );
      }

      // Check file format by magic numbers
      final isValidFormat = _isValidImageFormat(bytes);
      if (!isValidFormat) {
        return ValidationResult(
          isValid: false,
          error: 'Invalid image format',
        );
      }

      // Try to decode image to get dimensions. Pure-Dart decode of a
      // camera capture (up to the 50 MB cap) takes hundreds of ms — run it
      // in an isolate and bring back only the dimensions.
      try {
        final dims = await compute(_readDimensions, bytes,
            debugLabel: 'imageDimensions');
        if (dims != null) {
          return ValidationResult(
            isValid: true,
            fileSize: bytes.length,
            width: dims.width,
            height: dims.height,
          );
        }
      } catch (e, st) {
        // If decode fails, still allow upload with format validation
        AppLogger.warn('Could not decode image dimensions',
            tag: 'image', error: e, stackTrace: st);
      }

      // Fallback: image format validated, assume valid
      return ValidationResult(
        isValid: true,
        fileSize: bytes.length,
        width: null,
        height: null,
      );
    } catch (e, st) {
      AppLogger.error('Validation error',
          tag: 'image', error: e, stackTrace: st);
      // Fail-safe: allow upload to continue
      return ValidationResult(
        isValid: true,
        fileSize: null,
        width: null,
        height: null,
      );
    }
  }

  /// Get image bytes from file
  static Future<Uint8List?> _getImageBytes(String imagePath) async {
    try {
      // On web, imagePath is a blob URL
      if (kIsWeb) {
        // For web, we'll skip file reading and rely on format validation
        // The image picker already validates the file on web
        return Uint8List(0); // Return empty bytes for web
      } else {
        final File imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          return null;
        }
        return await imageFile.readAsBytes();
      }
    } catch (e, st) {
      AppLogger.error('Error reading image bytes',
          tag: 'image', error: e, stackTrace: st);
      return null;
    }
  }

  /// Check if file is valid image format
  static bool _isValidImageFormat(List<int> bytes) {
    // For web, skip magic number validation as bytes might be empty
    if (kIsWeb && bytes.isEmpty) {
      return true; // Trust browser's file picker validation
    }

    if (bytes.length < 4) {
      // On web, allow through even if we can't read bytes
      return kIsWeb;
    }

    // Check magic numbers for common formats
    try {
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return true;
      }

      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return true;
      }

      // WebP: RIFF ... WEBP
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        if (bytes.length >= 12 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50) {
          return true;
        }
      }

      // GIF: 47 49 46 38
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return true;
      }

      // BMP: 42 4D
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return true;
      }
    } catch (e, st) {
      AppLogger.error('Error checking image format',
          tag: 'image', error: e, stackTrace: st);
      return kIsWeb; // Trust web picker if check fails
    }

    return false;
  }

  /// Get compressed file size percentage
  static String getCompressionPercentage(int originalSize, int compressedSize) {
    try {
      // Handle web where compressedSize might be 0
      if (originalSize == 0 || compressedSize == 0) {
        return '0';
      }
      final percentage =
          ((originalSize - compressedSize) / originalSize * 100);
      return percentage.toStringAsFixed(1);
    } catch (e, st) {
      AppLogger.error('Error calculating compression',
          tag: 'image', error: e, stackTrace: st);
      return '0';
    }
  }
}

/// Result of image validation
class ValidationResult {
  final bool isValid;
  final String? error;
  final int? fileSize;
  final int? width;
  final int? height;

  ValidationResult({
    required this.isValid,
    this.error,
    this.fileSize,
    this.width,
    this.height,
  });

  String get sizeDisplay {
    if (fileSize == null) return '';
    final mb = fileSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String get dimensionsDisplay {
    if (width == null || height == null) return '';
    return '${width}x${height}px';
  }
}
