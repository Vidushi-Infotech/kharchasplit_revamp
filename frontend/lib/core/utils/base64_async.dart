import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Base64 encode / decode off the main isolate.
///
/// Receipts and cover images are shipped as base64 strings in JSON bodies.
/// Encoding a 3 MB camera capture, or decoding one for display, takes long
/// enough on a mid-range phone to drop several frames if done on the main
/// isolate — the UI freezes for the duration. Anything above
/// [isolateThresholdBytes] is therefore pushed through [compute]; small
/// payloads (avatars, thumbnails) stay inline because spawning an isolate
/// costs more than the work itself.
///
/// On web `compute` runs on the same thread, which is fine — there is no
/// isolate to offload to and the payloads are typically smaller there.
const int isolateThresholdBytes = 64 * 1024;

Future<String> base64EncodeAsync(Uint8List bytes) {
  if (bytes.length < isolateThresholdBytes) {
    return Future.value(base64Encode(bytes));
  }
  return compute(_encode, bytes, debugLabel: 'base64Encode');
}

/// Returns `null` for malformed input instead of throwing. Accepts both raw
/// base64 and `data:image/...;base64,` data URLs.
Future<Uint8List?> base64DecodeAsync(String data) {
  final cleaned = data.contains(',') ? data.split(',').last : data;
  if (cleaned.length < isolateThresholdBytes) {
    return Future.value(_decode(cleaned));
  }
  return compute(_decode, cleaned, debugLabel: 'base64Decode');
}

String _encode(Uint8List bytes) => base64Encode(bytes);

Uint8List? _decode(String cleaned) {
  try {
    return base64Decode(cleaned);
  } on FormatException {
    return null;
  }
}
