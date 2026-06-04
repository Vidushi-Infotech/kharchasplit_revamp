import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Module-level cache so re-renders of the same group (e.g. the same
/// group shown in the dashboard tile AND the groups list) collapse to
/// one decode per base64 string rather than one per rebuild.
const int _coverDecodeMaxEntries = 50;
final Map<String, Uint8List> _coverDecodeCache = {};

Uint8List? _decodeCoverBase64(String input) {
  final cached = _coverDecodeCache[input];
  if (cached != null) {
    _coverDecodeCache.remove(input);
    _coverDecodeCache[input] = cached;
    return cached;
  }
  try {
    var src = input;
    final comma = src.indexOf(',');
    if (src.startsWith('data:') && comma > 0) src = src.substring(comma + 1);
    final bytes = base64Decode(src);
    if (_coverDecodeCache.length >= _coverDecodeMaxEntries) {
      _coverDecodeCache.remove(_coverDecodeCache.keys.first);
    }
    _coverDecodeCache[input] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// Renders a group's cover. Shows the base64 photo when present,
/// otherwise falls back to the emoji (or a generic icon if the emoji is
/// the default people glyph). Centralises the logic so every place that
/// shows a group (grid card, row card, detail header, dashboard tiles)
/// agrees on what a group looks like.
class GroupCoverThumb extends StatelessWidget {
  const GroupCoverThumb({
    super.key,
    required this.coverImageBase64,
    required this.coverEmoji,
    required this.size,
    this.borderRadius = 14,
    this.backgroundColor,
    this.emojiFontSize,
    this.fallbackIcon = Icons.group_rounded,
    this.fallbackIconColor,
  });

  final String? coverImageBase64;
  final String coverEmoji;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final double? emojiFontSize;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;

  bool get _hasImage =>
      coverImageBase64 != null && coverImageBase64!.trim().isNotEmpty;

  Uint8List? _decode() => _decodeCoverBase64(coverImageBase64!);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    if (_hasImage) {
      final bytes = _decode();
      if (bytes != null) {
        return ClipRRect(
          borderRadius: radius,
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _emojiFallback(),
          ),
        );
      }
    }
    return _emojiFallback();
  }

  Widget _emojiFallback() {
    final hasCustomEmoji = coverEmoji.isNotEmpty && coverEmoji != '👥';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: hasCustomEmoji
          ? Text(
              coverEmoji,
              style: TextStyle(fontSize: emojiFontSize ?? (size * 0.5)),
            )
          : Icon(
              fallbackIcon,
              size: (emojiFontSize ?? size * 0.5),
              color: fallbackIconColor,
            ),
    );
  }
}
