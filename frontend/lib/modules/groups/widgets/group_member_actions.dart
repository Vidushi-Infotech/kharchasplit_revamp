import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/groups_provider.dart';
import 'contacts_picker_sheet.dart';
import 'email_invite_sheet.dart';

Future<void> showGroupInviteDialog(
  String groupId,
  BuildContext context,
  WidgetRef ref,
) async {
  // Pull current members so the picker can mark them as already-added.
  final loaded = ref.read(groupDetailProvider(groupId)).value;
  final existingPhones =
      loaded?.members.map((m) => m.phone).where((p) => p.isNotEmpty) ??
      const <String>[];

  final selfPhone = ref.read(authProvider).user?.phone ?? '';
  final picked = await showContactsPicker(
    context,
    doneLabel: 'Add',
    existingMemberPhones: existingPhones,
    selfPhones: selfPhone.isEmpty ? const [] : [selfPhone],
  );
  if (picked.isEmpty || !context.mounted) return;

  final repo = ref.read(groupsRepositoryProvider);
  int added = 0;
  final failures = <String>[];

  int emailsSent = 0;
  int emailsFailed = 0;

  for (final c in picked) {
    final phone = c.phones.isNotEmpty ? c.phones.first.number.trim() : '';
    final email = c.emails.isNotEmpty ? c.emails.first.address.trim() : '';
    final name = c.displayName.trim().isEmpty
        ? (phone.isNotEmpty ? phone : email)
        : c.displayName.trim();

    if (phone.isNotEmpty) {
      try {
        await repo.invitePhone(
          groupId: groupId,
          name: name,
          phoneNumber: phone,
        );
        added++;
      } catch (e) {
        failures.add(
          '${c.displayName}: ${e is GroupsApiException ? e.message : e}',
        );
      }
    } else if (email.isEmpty) {
      // Neither phone nor email — nothing we can do.
      failures.add('${c.displayName} (no phone or email)');
      continue;
    }

    // Email fallback — fires whenever the picker popup collected an
    // email for this contact (regardless of whether WATI accepted it).
    if (email.isNotEmpty) {
      try {
        await repo.inviteByEmail(groupId: groupId, email: email, name: name);
        emailsSent++;
      } catch (_) {
        emailsFailed++;
      }
    }
  }

  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(groupsProvider);

  if (!context.mounted) return;
  final parts = <String>[];
  if (added > 0) {
    parts.add('$added added');
  }
  if (emailsSent > 0) {
    parts.add('$emailsSent email${emailsSent == 1 ? '' : 's'} sent');
  }
  if (failures.isNotEmpty) {
    parts.add('${failures.length} failed');
  }
  if (emailsFailed > 0) {
    parts.add('$emailsFailed email${emailsFailed == 1 ? '' : 's'} failed');
  }
  final msg = parts.isEmpty ? 'No changes' : parts.join(' · ');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> sendGroupReminder(
  String groupId,
  BuildContext context,
  WidgetRef ref,
  UserModel debtor,
) async {
  try {
    await ref
        .read(groupsRepositoryProvider)
        .sendReminder(groupId: groupId, userId: debtor.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminded ${debtor.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } on GroupsApiException catch (e) {
    // Backend rejects with 400 (nothing owed), 429 (cooldown), 404, etc.
    // Surface the message verbatim so the user sees the real reason.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not send reminder: $e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> showEmailInviteDialog(
  String groupId,
  BuildContext context,
  WidgetRef ref,
  UserModel member,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final email = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => EmailInviteSheet(memberName: member.name, isDark: isDark),
  );
  if (email == null || email.isEmpty || !context.mounted) return;
  try {
    await ref
        .read(groupsRepositoryProvider)
        .inviteByEmail(groupId: groupId, email: email, name: member.name);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invite sent to $email')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send invite: $e')));
    }
  }
}
