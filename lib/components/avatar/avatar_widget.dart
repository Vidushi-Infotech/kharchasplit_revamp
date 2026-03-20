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
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  /// Get background color based on name (consistent for same name)
  Color _getBackgroundColor(String name) {
    final colors = [
      Colors.red[400],
      Colors.pink[400],
      Colors.purple[400],
      Colors.deepPurple[400],
      Colors.indigo[400],
      Colors.blue[400],
      Colors.cyan[400],
      Colors.teal[400],
      Colors.green[400],
      Colors.lime[400],
      Colors.amber[400],
      Colors.orange[400],
    ];
    final index = name.hashCode % colors.length;
    return colors[index] ?? Colors.blue;
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
                ? _buildNetworkImage()
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
                  color: isOnline ? Colors.green : Colors.grey[400],
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

  Widget _buildNetworkImage() {
    return CircleAvatar(
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(imageUrl!),
      backgroundColor: Colors.grey[300],
      onBackgroundImageError: (exception, stackTrace) {
        // Fallback to initials on error
      },
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        placeholder: (context, url) => _buildInitialAvatar(true),
        errorWidget: (context, url, error) => _buildInitialAvatar(true),
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

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: radius * 2,
        width: radius * 2 * 0.6 * displayCount + (remainingCount > 0 ? 24 : 0),
        child: Stack(
          children: [
            // Display avatars
            for (int i = 0; i < displayCount; i++)
              Positioned(
                left: i * (radius * 1.2),
                child: AvatarWidget(
                  name: names[i],
                  imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                  radius: radius,
                  borderWidth: 2,
                  borderColor: Colors.white,
                ),
              ),
            // Remaining count badge
            if (remainingCount > 0)
              Positioned(
                left: displayCount * (radius * 1.2),
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    '+${remainingCount}',
                    style: TextStyle(
                      fontSize: radius * 0.8,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
