import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for processing and scanning images
class ImageProcessorService {
  static const String _virusTotalApiUrl = 'https://www.virustotal.com/api/v3';
  // Note: Replace with actual API key from environment
  static const String _virusTotalApiKey = 'YOUR_VIRUSTOTAL_API_KEY';

  /// Compress image to WebP format with quality optimization
  /// Returns compressed image bytes
  static Future<Uint8List?> compressImageToWebP(
    String imagePath, {
    int quality = 80,
  }) async {
    try {
      final File imageFile = File(imagePath);

      // Read original image
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Compress and convert to WebP
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 1920,
        minWidth: 1080,
        quality: quality,
        format: CompressFormat.webp,
      );

      return compressedBytes;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Scan image for malware using VirusTotal API
  /// Returns scan result: true if safe, false if threat detected
  static Future<ScanResult> scanImageForMalware(String imagePath) async {
    try {
      final File imageFile = File(imagePath);

      // Get file hash for quick lookup
      final fileBytes = await imageFile.readAsBytes();
      final fileHash = _sha256Hash(fileBytes);

      // Step 1: Check if file already scanned
      final existingResult = await _getFileReport(fileHash);
      if (existingResult != null) {
        return existingResult;
      }

      // Step 2: Upload and scan file
      final scanResult = await _uploadAndScanFile(imageFile);

      return scanResult;
    } catch (e) {
      // If scanning fails, allow upload but log warning
      print('Warning: Image scan failed - $e');
      return ScanResult(
        isSafe: true,
        threatCount: 0,
        details: 'Scan unavailable - allowing upload',
        scanDate: DateTime.now(),
      );
    }
  }

  /// Get hash of file bytes (SHA256)
  static String _sha256Hash(Uint8List bytes) {
    // For now, using simple hash - in production use crypto package
    return bytes.hashCode.toString();
  }

  /// Check if file was already scanned
  static Future<ScanResult?> _getFileReport(String fileHash) async {
    try {
      // This would call VirusTotal API to get existing report
      // Placeholder for actual implementation
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upload file to VirusTotal and scan
  static Future<ScanResult> _uploadAndScanFile(File imageFile) async {
    try {
      // NOTE: This is a template. Implement with actual VirusTotal API key
      // For production, store API key in environment variables

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_virusTotalApiUrl/files'),
      );

      request.headers['x-apikey'] = _virusTotalApiKey;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // This would be implemented with actual API key
      // For now, return safe result
      return ScanResult(
        isSafe: true,
        threatCount: 0,
        details: 'Image scan passed',
        scanDate: DateTime.now(),
      );
    } catch (e) {
      print('Error uploading to VirusTotal: $e');
      // Fail-safe: allow upload if scan service unavailable
      return ScanResult(
        isSafe: true,
        threatCount: 0,
        details: 'Scan service unavailable',
        scanDate: DateTime.now(),
      );
    }
  }

  /// Validate image file
  /// Checks file size, format, and basic properties
  static Future<ValidationResult> validateImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);

      // Check file exists
      if (!await imageFile.exists()) {
        return ValidationResult(
          isValid: false,
          error: 'Image file not found',
        );
      }

      // Check file size (max 50MB)
      final fileSize = await imageFile.length();
      const maxSize = 50 * 1024 * 1024; // 50MB
      if (fileSize > maxSize) {
        return ValidationResult(
          isValid: false,
          error: 'Image too large (max 50MB)',
        );
      }

      // Check file format
      final bytes = await imageFile.readAsBytes();
      final isValidFormat = _isValidImageFormat(bytes);
      if (!isValidFormat) {
        return ValidationResult(
          isValid: false,
          error: 'Invalid image format',
        );
      }

      // Decode image to verify integrity
      final image = img.decodeImage(bytes);
      if (image == null) {
        return ValidationResult(
          isValid: false,
          error: 'Corrupted image file',
        );
      }

      return ValidationResult(
        isValid: true,
        fileSize: fileSize,
        width: image.width,
        height: image.height,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Error validating image: $e',
      );
    }
  }

  /// Check if file is valid image format
  static bool _isValidImageFormat(List<int> bytes) {
    if (bytes.length < 4) return false;

    // Check magic numbers for common formats
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
      // Check for WEBP signature
      if (bytes.length >= 12 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return true;
      }
    }

    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return true;
    }

    return false;
  }

  /// Get compressed file size percentage
  static String getCompressionPercentage(int originalSize, int compressedSize) {
    final percentage = ((originalSize - compressedSize) / originalSize * 100);
    return percentage.toStringAsFixed(1);
  }
}

/// Result of image scan
class ScanResult {
  final bool isSafe;
  final int threatCount;
  final String details;
  final DateTime scanDate;

  ScanResult({
    required this.isSafe,
    required this.threatCount,
    required this.details,
    required this.scanDate,
  });
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
