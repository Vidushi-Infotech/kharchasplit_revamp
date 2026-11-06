import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import 'app_logger.dart';

/// Turns any photo (receipt, group cover, profile picture) into a small
/// WebP before it's sent, so an upload never gets refused for its size.
///
/// The server sits behind a proxy that refuses request bodies over about
/// 128 KB, and base64 makes a photo a third bigger. So a photo is shrunk,
/// step by step, until it fits in [maxBytes]: first lower quality, then
/// fewer pixels, keeping receipts readable for as long as possible.
abstract final class UploadImage {
  /// About 107 KB once in base64, leaving room for the rest of the request.
  static const maxBytes = 80 * 1024;

  /// Short side, in pixels, per kind of photo.
  static const receiptSide = 1280;
  static const coverSide = 1080;
  static const avatarSide = 512;

  /// The smaller WebP (JPEG on the web) of [bytes], at most [maxSide]
  /// pixels on its short side. Never fails: if nothing can be encoded,
  /// the original comes back.
  static Future<Uint8List> shrink(
    Uint8List bytes, {
    int maxSide = receiptSide,
    int limit = maxBytes,
  }) async {
    try {
      return await shrinkWith(
        bytes,
        maxSide: maxSide,
        limit: limit,
        encode: kIsWeb ? _encodeWeb : _encodeNative,
      );
    } catch (e, st) {
      AppLogger.warn(
        'Photo not shrunk',
        tag: 'image',
        error: e,
        stackTrace: st,
      );
      return bytes;
    }
  }

  /// The (short side, quality) tries, best first.
  @visibleForTesting
  static List<(int, int)> steps(int maxSide) => [
    (maxSide, 80),
    (maxSide, 65),
    for (final (side, q) in const [
      (1080, 60),
      (900, 55),
      (768, 50),
      (640, 45),
      (512, 40),
      (384, 40),
    ])
      if (side < maxSide) (side, q),
  ];

  /// [shrink] with the encoder passed in (tests use a fake one).
  @visibleForTesting
  static Future<Uint8List> shrinkWith(
    Uint8List bytes, {
    required int maxSide,
    required int limit,
    required Future<Uint8List?> Function(Uint8List, int side, int quality)
    encode,
  }) async {
    Uint8List? smallest;
    for (final (side, quality) in steps(maxSide)) {
      final out = await encode(bytes, side, quality);
      if (out == null || out.isEmpty) continue;
      if (smallest == null || out.length < smallest.length) smallest = out;
      if (out.length <= limit) return out;
    }
    // Nothing fit: the smallest try still beats the original.
    if (smallest != null && smallest.length < bytes.length) return smallest;
    return bytes;
  }

  /// Android / iOS: native WebP, upright (EXIF rotation applied, EXIF
  /// dropped, so no location leaves the phone).
  static Future<Uint8List?> _encodeNative(
    Uint8List bytes,
    int side,
    int quality,
  ) => FlutterImageCompress.compressWithList(
    bytes,
    minWidth: side,
    minHeight: side,
    quality: quality,
    format: CompressFormat.webp,
  );

  /// Web: no WebP encoder, so a JPEG, made off the main thread.
  static Future<Uint8List?> _encodeWeb(
    Uint8List bytes,
    int side,
    int quality,
  ) => compute(_jpeg, (bytes: bytes, side: side, quality: quality));
}

Uint8List? _jpeg(({Uint8List bytes, int side, int quality}) a) {
  final decoded = img.decodeImage(a.bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final short = upright.width < upright.height ? upright.width : upright.height;
  final resized = short <= a.side
      ? upright
      : upright.width < upright.height
      ? img.copyResize(upright, width: a.side)
      : img.copyResize(upright, height: a.side);
  return img.encodeJpg(resized, quality: a.quality);
}
