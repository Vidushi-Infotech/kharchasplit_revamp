import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';

/// Avatar widget with network image, initials fallback, and stacking support
class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final VoidCallback? onTap;
  final double? borderWidth;
  final Color? borderColor;

  const AvatarWidget({
    Key? key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onTap,
    this.borderWidth,
    this.borderColor,
  }) : super(key: key);

  /// Get initials from name (e.g., "John Doe" → "JD")
  String _getInitials(String name) {
    final parts =
        name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  /// Get background color based on name (consistent for same name)
  Color _getBackgroundColor(String name) {
    final index = name.hashCode.abs() % AppColors.avatarColors.length;
    return AppColors.avatarColors[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: borderWidth != null && borderColor != null
                  ? Border.all(color: borderColor!, width: borderWidth!)
                  : null,
            ),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? _buildImage(isDark)
                : _buildInitialAvatar(isDark),
          ),
          // Online indicator
          if (showOnlineIndicator)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: radius * 0.6,
                height: radius * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppColors.online : AppColors.offline(isDark),
                  border: Border.all(
                    color: AppColors.background(isDark),
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(bool isDark) {
    final raw = imageUrl!;
    // Backend stores profile photos as a raw base64 string in the same
    // field as URLs — detect which one we got.
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return _buildNetworkImage(raw, isDark);
    }
    final memoryProvider = _decodeBase64(raw);
    if (memoryProvider == null) return _buildInitialAvatar(isDark);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _getBackgroundColor(name),
      backgroundImage: memoryProvider,
    );
  }

  MemoryImage? _decodeBase64(String input) {
    try {
      final cleaned = input.contains(',') ? input.split(',').last : input;
      return MemoryImage(base64Decode(cleaned));
    } catch (_) {
      return null;
    }
  }

  Widget _buildNetworkImage(String url, bool isDark) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(url),
      backgroundColor: Colors.grey[300],
      onBackgroundImageError: (exception, stackTrace) {
        // Fallback to initials on error
      },
      child: CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        placeholder: (context, _) => _buildInitialAvatar(isDark),
        errorWidget: (context, _, __) => _buildInitialAvatar(isDark),
      ),
    );
  }

  Widget _buildInitialAvatar(bool isDark) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _getBackgroundColor(name),
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Stacked avatars widget for displaying multiple avatars overlapped
class StackedAvatarsWidget extends StatelessWidget {
  final List<String> names;
  final List<String?> imageUrls;
  final double radius;
  final int maxVisible;
  final VoidCallback? onTap;

  const StackedAvatarsWidget({
    Key? key,
    required this.names,
    required this.imageUrls,
    this.radius = 16,
    this.maxVisible = 3,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayCount = (names.length > maxVisible) ? maxVisible : names.length;
    final remainingCount = names.length - displayCount;
    // Calculate width: spacing between avatars + final avatar diameter + padding
    // Using 1.8x spacing to prevent any cropping with borders
    final spacing = radius * 1.8;
    final width = displayCount > 0
        ? (displayCount - 1) * spacing + (radius * 2) + 8
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: radius * 2 + 8,
        width: (remainingCount > 0 ? width + 24 : width).toDouble(),
        child: Stack(
          children: [
            // Display avatars
            for (int i = 0; i < displayCount; i++)
              Positioned(
                left: (i * spacing).toDouble(),
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return AvatarWidget(
                      name: names[i],
                      imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                      radius: radius,
                      borderWidth: 2,
                      borderColor: AppColors.surface(isDark),
                    );
                  },
                ),
              ),
            // Remaining count badge
            if (remainingCount > 0)
              Positioned(
                left: (displayCount * spacing).toDouble(),
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return CircleAvatar(
                      radius: radius,
                      backgroundColor: AppColors.divider(isDark),
                      child: Text(
                        '+${remainingCount}',
                        style: TextStyle(
                          fontSize: radius * 0.8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
