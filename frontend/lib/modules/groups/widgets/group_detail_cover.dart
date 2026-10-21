import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../models/group_model.dart';
import '../state/group_display.dart';
import 'group_cover_thumb.dart';

/// Cover shown in the group detail headers: the group's photo / emoji, or
/// — for non-group expenses with one friend — that friend's avatar, since
/// the hidden direct group has no cover of its own.
class GroupDetailCover extends StatelessWidget {
  const GroupDetailCover({
    super.key,
    required this.group,
    required this.myId,
    required this.size,
    required this.borderRadius,
    required this.emojiFontSize,
    this.fallbackIconColor,
  });

  final GroupModel group;
  final String? myId;
  final double size;
  final double borderRadius;
  final double emojiFontSize;
  final Color? fallbackIconColor;

  @override
  Widget build(BuildContext context) {
    final friend = group.directFriend(myId);
    if (friend != null) {
      return AvatarWidget(
        imageUrl: friend.avatarUrl,
        name: friend.name,
        radius: size / 2,
      );
    }
    return GroupCoverThumb(
      coverImageBase64: group.coverImageBase64,
      coverEmoji: group.coverEmoji,
      size: size,
      borderRadius: borderRadius,
      emojiFontSize: emojiFontSize,
      fallbackIconColor: fallbackIconColor,
    );
  }
}
