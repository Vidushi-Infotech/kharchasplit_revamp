import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/add_friend_provider.dart';

/// What the "Add friend" lookup found: a spinner, the person to confirm
/// ("Asha · …1234" + Add friend), "that's you", "Not on KharchaSplit yet"
/// with Invite, or an error. Nothing before the first Find.
class AddFriendResult extends StatelessWidget {
  const AddFriendResult({super.key, required this.state, required this.onAdd});

  final AddFriendState state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (state.status) {
      case AddFriendStatus.idle:
        return const SizedBox.shrink();
      case AddFriendStatus.looking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );
      case AddFriendStatus.error:
        return _Message(
          icon: Icons.error_outline_rounded,
          color: AppColors.warning,
          text: state.error ?? AppStrings.lookupFailed,
          isDark: isDark,
        );
      case AddFriendStatus.self:
        return _Message(
          icon: Icons.person_outline_rounded,
          color: AppColors.textSecondary(isDark),
          text: AppStrings.thatIsYourNumber,
          isDark: isDark,
        );
      case AddFriendStatus.notFound:
        return _NotRegistered(isDark: isDark);
      case AddFriendStatus.found:
      case AddFriendStatus.adding:
        return _Found(state: state, onAdd: onAdd, isDark: isDark);
    }
  }
}

class _Found extends StatelessWidget {
  const _Found({
    required this.state,
    required this.onAdd,
    required this.isDark,
  });

  final AddFriendState state;
  final VoidCallback onAdd;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hit = state.result!;
    final adding = state.status == AddFriendStatus.adding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: AvatarWidget(
              imageUrl: hit.avatarUrl,
              name: hit.name,
              radius: 22,
            ),
            title: Text(
              hit.name,
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: hit.phoneSuffix.isEmpty
                ? null
                : Text(
                    '…${hit.phoneSuffix}',
                    style: AppTextStyles.caption(isDark),
                  ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.error!,
              style: AppTextStyles.caption(
                isDark,
              ).copyWith(color: AppColors.errorText(isDark)),
            ),
          ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: '${AppStrings.addFriend} ${hit.name}',
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: adding ? null : onAdd,
            icon: adding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.person_add_alt_1_rounded),
            label: const Text(AppStrings.addFriend),
          ),
        ),
      ],
    );
  }
}

class _NotRegistered extends StatelessWidget {
  const _NotRegistered({required this.isDark});
  final bool isDark;

  Future<void> _invite() => SharePlus.instance.share(
    ShareParams(text: addFriendInviteText, subject: 'KharchaSplit'),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.notOnKharchaSplitYet,
          style: AppTextStyles.body1(
            isDark,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.notOnKharchaSplitHint,
          style: AppTextStyles.body2(
            isDark,
          ).copyWith(color: AppColors.textSecondary(isDark)),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Invite to KharchaSplit',
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _invite,
            icon: const Icon(Icons.share_rounded),
            label: const Text(AppStrings.invite),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.text,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body2(isDark).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
