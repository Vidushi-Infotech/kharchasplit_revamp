import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../components/components.dart';
import '../../../models/user_model.dart';
import 'group_member_actions.dart';
import 'remove_member_actions.dart';

const String _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.kharchasplit';
const String _kAppStoreUrl =
    'https://apps.apple.com/in/app/kharchasplit/id6754237285';
const String _kInviteMessage =
    "Hey! You've been added to a group on KharchaSplit, the easiest way to "
    "split expenses with friends. Download the app to get started!\n\n"
    "Android: $_kPlayStoreUrl\n"
    "iOS: $_kAppStoreUrl";

Future<void> showMemberActionsSheet({
  required String groupId,
  required BuildContext context,
  required WidgetRef ref,
  required UserModel member,
  required bool isAdmin,
  required bool isSelf,
  bool isDirect = false,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final canRemove = isAdmin && !isSelf && !isDirect;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  AvatarWidget(
                    imageUrl: member.avatarUrl,
                    name: member.name,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSelf ? '${member.name} (you)' : member.name,
                          style: AppTextStyles.body1(
                            isDark,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (member.phone.isNotEmpty)
                          Text(
                            member.phone,
                            style: AppTextStyles.caption(
                              isDark,
                            ).copyWith(color: AppColors.textSecondary(isDark)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (member.isPlaceholder) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Not yet on KharchaSplit',
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Group email invites are rejected on non-group expenses
                // (DIRECT_GROUP); the WhatsApp / copy-link invites below
                // only invite them to the app.
                if (!isDirect) ...[
                  SheetAction(
                    icon: Icons.email_outlined,
                    label: 'Invite on Mail',
                    color: AppColors.brand,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      showEmailInviteDialog(groupId, context, ref, member);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (member.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SheetAction(
                      icon: Icons.message_rounded,
                      label: 'Invite on WhatsApp',
                      color: const Color(0xFF25D366),
                      isDark: isDark,
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        // Opens WhatsApp directly in this member's chat with
                        // the invite pre-filled; the user just taps Send.
                        final ok = await openWhatsAppChat(
                          phone: member.phone,
                          message: _kInviteMessage,
                        );
                        if (ok || !context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open WhatsApp. Is it installed?',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SheetAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy Invite Link',
                  color: AppColors.textSecondary(isDark),
                  isDark: isDark,
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: _kInviteMessage),
                    );
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite message copied to clipboard'),
                      ),
                    );
                  },
                ),
              ],
              if (canRemove) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.errorText(isDark),
                    ),
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('Remove from group'),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      confirmRemoveMember(groupId, context, ref, member);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
