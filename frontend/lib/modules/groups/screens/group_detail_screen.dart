import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/edit_group_sheet.dart';
import '../widgets/group_cover_thumb.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/components.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/group_model.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../settlements/state/pending_settlements_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/groups_provider.dart';
import '../../../core/services/haptic_service.dart';
import '../widgets/contacts_picker_sheet.dart';
import '../widgets/group_activity_tab.dart';
import '../widgets/balance_summary_cards.dart';
import '../widgets/balance_expense_logs.dart';

/// Slim sticky header that hosts the 3-tab bar (Expenses / Balances /
/// Activity). Pinned in a NestedScrollView so the group hero card scrolls
/// away while the tabs remain visible at the top.
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyTabBarDelegate({
    required this.child,
    required this.isDark,
    this.height = 58,
  });

  final Widget child;
  final bool isDark;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      // Match the screen background so the pinned bar blends in when the
      // hero card has scrolled past, and a 1-px hairline divider separates
      // it from the content below.
      color: AppColors.background(isDark),
      elevation: overlapsContent ? 1 : 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: child),
          Container(
            height: 1,
            color: AppColors.divider(isDark).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.isDark != isDark ||
      oldDelegate.height != height;
}

const String _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.kharchasplit';
const String _kAppStoreUrl =
    'https://apps.apple.com/in/app/kharchasplit/id6754237285';
const String _kInviteMessage =
    "Hey! You've been added to a group on KharchaSplit — the easiest way to "
    "split expenses with friends. Download the app to get started!\n\n"
    "Android: $_kPlayStoreUrl\n"
    "iOS: $_kAppStoreUrl";

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final myId = ref.watch(myIdProvider);
    final loadedDetail = detailAsync.value;
    final isAdmin =
        loadedDetail != null &&
        myId != null &&
        loadedDetail.group.createdBy == myId;

    // NOTE on the inner Consumers below: `tab` deliberately is NOT
    // watched here in the outer build. Tab switches are the most
    // frequent state change on this screen; without the inner scoping
    // every switch would rebuild the entire 2946-line widget tree
    // (including _DetailTopBar, layout switches, and the refresh
    // indicator). Confining the tab watch to the body + FAB Consumers
    // means tab changes only repaint those two regions.
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _DetailTopBar(
        isDark: isDark,
        isAdmin: isAdmin,
        canManage: loadedDetail != null && myId != null,
        onClose: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home/groups');
          }
        },
        onAddMember: () => _showInviteDialog(context, ref),
        onEditGroup: loadedDetail == null
            ? null
            : () => _openEditGroupSheet(context, ref, loadedDetail.group),
        onLeaveGroup: () => _confirmLeaveGroup(context, ref, myId),
        onDeleteGroup: () => _confirmDeleteGroup(context, ref),
        onExportGroup: loadedDetail == null
            ? null
            : () => _exportGroup(context, ref, loadedDetail.group),
      ),
      body: detailAsync.when(
        loading: () => const ShimmerList(type: ShimmerListType.group),
        error: (err, stack) => _buildErrorState(context, ref, err),
        data: (detail) => Consumer(
          builder: (context, ref, _) {
            final tab = ref.watch(groupTabProvider);
            final body = screenWidth < 600
                ? _buildCompactLayout(
                    context,
                    isDark,
                    detail,
                    tab,
                    ref,
                    myId,
                    isAdmin,
                  )
                : screenWidth < 1100
                    ? _buildStandardLayout(
                        context,
                        isDark,
                        detail,
                        tab,
                        ref,
                        myId,
                        isAdmin,
                      )
                    : _buildLargeLayout(
                        context,
                        isDark,
                        detail,
                        tab,
                        ref,
                        myId,
                        isAdmin,
                      );
            // Outer RefreshIndicator catches pulls from the very TOP of the
            // header (above the sticky tab bar). Each tab body below also
            // has its own RefreshIndicator so the swipe works from inside
            // the list / scroll view — see _buildTabBody. All three call
            // the same _refreshAllTabs so any pull always reloads the
            // group's full state (balances, expenses, members, activity,
            // pending settlements).
            return RefreshIndicator(
              onRefresh: () => _refreshAllTabs(ref),
              child: body,
            );
          },
        ),
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final tab = ref.watch(groupTabProvider);
          if (tab != GroupTab.expenses) return const SizedBox.shrink();
          return Semantics(
            button: true,
            label: 'Add expense button',
            onTap: () => _navigateToAddExpense(context),
            child: FloatingActionButton(
              onPressed: () => _navigateToAddExpense(context),
              backgroundColor: AppColors.brand,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    context.pushNamed(
      'add-expense-to-group',
      pathParameters: {'groupId': groupId},
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object err) {
    final status = err is GroupsApiException ? err.statusCode : null;
    final isAccessDenied = status == 403;
    final isMissing = status == 404;

    final title = isAccessDenied
        ? "You don't have access to this group"
        : isMissing
        ? 'This group no longer exists'
        : 'Failed to load group details';
    final message = isAccessDenied
        ? "It looks like you're no longer a member, or this group belongs to a different account."
        : isMissing
        ? "The group may have been deleted. Pick another from your list."
        : (err is GroupsApiException ? err.message : err.toString());

    final showRetry = !isAccessDenied && !isMissing;

    return ErrorStateWidget(
      title: title,
      message: message,
      onRetry: showRetry
          ? () => ref.invalidate(groupDetailProvider(groupId))
          : null,
      onSecondaryAction: () => context.go('/home/groups'),
      secondaryActionLabel: 'Back to Groups',
    );
  }

  /// Open the bottom sheet for editing the group's name + cover photo.
  /// Admin-only at the call site; backend also enforces. Refreshes the
  /// detail provider on save so the header re-renders with new data.
  Future<void> _openEditGroupSheet(
    BuildContext context,
    WidgetRef ref,
    GroupModel group,
  ) async {
    final updated = await EditGroupSheet.show(context, group: group);
    if (updated == null || !context.mounted) return;
    ref.invalidate(groupDetailProvider(group.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Group updated'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
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

  Future<void> _showMemberActionsSheet({
    required BuildContext context,
    required WidgetRef ref,
    required UserModel member,
    required bool isAdmin,
    required bool isSelf,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canRemove = isAdmin && !isSelf;

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
                              style: AppTextStyles.caption(isDark).copyWith(
                                color: AppColors.textSecondary(isDark),
                              ),
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
                  _SheetAction(
                    icon: Icons.email_outlined,
                    label: 'Invite on Mail',
                    color: AppColors.brand,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _showEmailInviteDialog(context, ref, member);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (member.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SheetAction(
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
                  _SheetAction(
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
                        _confirmRemoveMember(context, ref, member);
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

  Future<void> _sendReminder(
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

  Future<void> _showEmailInviteDialog(
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
      builder: (ctx) =>
          _EmailInviteSheet(memberName: member.name, isDark: isDark),
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

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    UserModel member,
  ) async {
    // Compute pairwise debts client-side from the already-loaded
    // detail so we can show the right dialog up-front — no
    // confirm → 409 → second dialog round trip. The 409 fallback
    // path in [_performRemoveMember] still catches the rare race
    // where the server saw debt the client didn't.
    final detail = ref.read(groupDetailProvider(groupId)).value;
    final pair = detail == null
        ? const <String, double>{}
        : _pairwiseDebts(myId: member.id, detail: detail);
    final unsettled = pair.entries
        .where((e) => e.value.abs() > 0.005)
        .toList(growable: false);

    if (unsettled.isNotEmpty) {
      // Surface the write-off dialog with debt details derived from
      // local state. UnsettledBalancesInfo's sign convention matches
      // _pairwiseDebts: positive → member owes the other party.
      final info = UnsettledBalancesInfo(
        memberId: member.id,
        memberName: member.name,
        currency: detail!.group.currency,
        pairwise: [
          for (final e in unsettled)
            PairwiseDebt(
              userId: e.key,
              userName:
                  detail.members.firstWhereOrNull((m) => m.id == e.key)?.name ??
                  'Unknown',
              amount: e.value,
            ),
        ],
      );
      HapticService.instance.error();
      final proceed = await _showWriteOffDialog(context, member, info);
      if (proceed != true || !context.mounted) return;
      HapticService.instance.destructive();
      await _performRemoveMember(context, ref, member, acknowledged: true);
      return;
    }

    // Clean member — simple confirm + single-shot removal.
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          "They'll lose access to this group's expenses. You can add them back any time.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText(
                Theme.of(ctx).brightness == Brightness.dark,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    HapticService.instance.destructive();
    await _performRemoveMember(context, ref, member, acknowledged: false);
  }

  /// Performs the actual `removeMember` call. On the first attempt
  /// `acknowledged` is false; if the backend rejects with the
  /// `UNSETTLED_BALANCES` code we surface a write-off dialog that
  /// recurses back here with `acknowledged: true`.
  Future<void> _performRemoveMember(
    BuildContext context,
    WidgetRef ref,
    UserModel member, {
    required bool acknowledged,
  }) async {
    try {
      await ref
          .read(groupsRepositoryProvider)
          .removeMember(
            groupId: groupId,
            userId: member.id,
            acknowledgeUnsettledDebt: acknowledged,
          );
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} removed from group.')),
      );
    } on GroupsApiException catch (e) {
      if (!context.mounted) return;
      // Backend's "you need to write off the unsettled debt first"
      // signal — open the second-step dialog instead of dumping the raw
      // message in a SnackBar.
      if (!acknowledged && e.code == 'UNSETTLED_BALANCES' && e.data != null) {
        HapticService.instance.error();
        final info = UnsettledBalancesInfo.fromJson(e.data!);
        final proceed = await _showWriteOffDialog(context, member, info);
        if (proceed == true && context.mounted) {
          HapticService.instance.destructive();
          await _performRemoveMember(context, ref, member, acknowledged: true);
        }
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }

  /// Second-step destructive dialog: lists every unsettled pairwise debt
  /// the member is part of, then offers a single "Write off & remove"
  /// red button. The user is informed in plain language that the writes
  /// are permanent and not recoverable by re-adding the member.
  Future<bool?> _showWriteOffDialog(
    BuildContext context,
    UserModel member,
    UnsettledBalancesInfo info,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = info.currency == 'INR' ? '₹' : info.currency;
    String fmt(double v) =>
        '$currency${v.abs().toStringAsFixed(v.abs() == v.abs().roundToDouble() ? 0 : 2)}';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${info.memberName} has unsettled balances'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Removing them will permanently write off the amounts '
              'below. The group balances will be cleaned up, but the '
              'underlying debts cannot be recovered if you add them '
              'back later.',
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final p in info.pairwise) _writeOffRow(p, fmt, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText(isDark),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Write off & remove'),
          ),
        ],
      ),
    );
  }

  Widget _writeOffRow(
    PairwiseDebt p,
    String Function(double) fmt,
    bool isDark,
  ) {
    // Sign convention from the backend payload: positive → the removed
    // member owes that party; negative → that party owes the removed
    // member. We always express the line from the removed member's
    // perspective so the admin reads a consistent narrative.
    final owes = p.amount > 0;
    final color = owes ? AppColors.errorText(isDark) : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              owes ? 'Owes ${p.userName}' : '${p.userName} owes them',
              style: AppTextStyles.body2(isDark).copyWith(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmt(p.amount),
            style: AppTextStyles.body2(
              isDark,
            ).copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    WidgetRef ref,
    String? myId,
  ) async {
    if (myId == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          "You can only leave once you've settled all balances with other members.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      await ref
          .read(groupsRepositoryProvider)
          .leave(groupId: groupId, userId: myId);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailProvider(groupId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Left the group.')));
      context.go('/home/groups');
    } on GroupsApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not leave: $e')));
    }
  }

  /// Download the group's .xlsx ledger and hand it to the OS share sheet so
  /// the user can save it anywhere (Drive, email, WhatsApp, Files…).
  ///
  /// Flow:
  ///   1. Show a non-dismissible spinner so the user knows work is happening.
  ///   2. Fetch bytes from `/groups/:id/export` via the repository.
  ///   3. Write bytes to a temp file in the platform temp dir (Android/iOS
  ///      both support this; the OS reaps the file on its own schedule).
  ///   4. Dismiss the spinner and call `Share.shareXFiles` so the user picks
  ///      a destination.
  ///
  /// Errors at any step surface as a snackbar — never crash, never silently
  /// fail.
  Future<void> _exportGroup(
    BuildContext context,
    WidgetRef ref,
    GroupModel group,
  ) async {
    HapticService.instance.selection();

    // 1. Spinner
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Download
      final result = await ref
          .read(groupsRepositoryProvider)
          .exportGroup(groupId);

      // 3. Write to temp
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${result.filename}');
      await file.writeAsBytes(result.bytes, flush: true);

      // 4. Dismiss spinner + share
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          subject: 'KharchaSplit — ${group.name} ledger',
          text:
              'Group ledger for "${group.name}" — exported from KharchaSplit.',
        ),
      );
    } on GroupsApiException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export: $e')));
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context, WidgetRef ref) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: const Text(
          'This permanently deletes the group for everyone. All expenses must already be settled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText(
                Theme.of(ctx).brightness == Brightness.dark,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    HapticService.instance.destructive();
    try {
      await ref.read(groupsRepositoryProvider).delete(groupId);
      ref.invalidate(groupsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group deleted.')));
      context.go('/home/groups');
    } on GroupsApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
    String? myId,
    bool isAdmin,
  ) {
    // Compact: <600px - full width, single column, tight spacing (16-20px)
    return NestedScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      headerSliverBuilder: (ctx, _) => [
        SliverToBoxAdapter(
          child: _buildCompactHeader(
            context,
            isDark,
            detail,
            ref,
            myId,
            isAdmin,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBarDelegate(
            isDark: isDark,
            child: _buildTabs(context, isDark, tab, ref),
          ),
        ),
      ],
      body: _buildTabBody(context, ref, isDark, tab, detail, myId),
    );
  }

  /// Invalidate every provider that feeds any of the 3 tabs on this screen,
  /// then await the main fetch so the [RefreshIndicator] hides at the
  /// moment fresh data lands. Called from:
  ///   * the outer RefreshIndicator (top-of-header pull)
  ///   * inline RefreshIndicators inside each tab body
  ///   * GroupActivityTab's onRefresh
  /// Same callback everywhere so users can pull from ANY tab and get the
  /// full group state refreshed in one shot.
  Future<void> _refreshAllTabs(WidgetRef ref) async {
    HapticService.instance.thresholdCrossed();
    ref.invalidate(groupDetailProvider(groupId));
    ref.invalidate(pendingIncomingSettlementsProvider(groupId));
    ref.invalidate(pendingOutgoingSettlementsProvider(groupId));
    // groupFeedProvider (activity feed) derives from groupDetailProvider, so
    // invalidating the parent above already refreshes the feed — no separate
    // invalidate call needed.
    await ref.read(groupDetailProvider(groupId).future);
  }

  /// Body for whichever tab is currently selected. Lives below the pinned
  /// tab bar inside [NestedScrollView]; each branch is responsible for its
  /// own internal scrolling.
  ///
  /// Each branch wraps its scrollable in a [RefreshIndicator] so the pull
  /// gesture works from anywhere inside the tab — not just when the user
  /// has scrolled to the absolute top (which is the only place the outer
  /// RefreshIndicator triggers when wrapping a [NestedScrollView]).
  Widget _buildTabBody(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    GroupTab tab,
    GroupDetail detail,
    String? myId,
  ) {
    switch (tab) {
      case GroupTab.expenses:
        return RefreshIndicator(
          onRefresh: () => _refreshAllTabs(ref),
          child: _buildExpensesList(context, isDark, detail),
        );
      case GroupTab.balances:
        return RefreshIndicator(
          onRefresh: () => _refreshAllTabs(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _buildBalancesTab(context, ref, isDark, detail, myId),
          ),
        );
      case GroupTab.activity:
        // GroupActivityTab has its own RefreshIndicator wired to the same
        // shared callback so all 3 tabs behave identically.
        return GroupActivityTab(
          groupId: groupId,
          onRefresh: () => _refreshAllTabs(ref),
        );
    }
  }

  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
    String? myId,
    bool isAdmin,
  ) {
    // Standard: 600-1100px — same sticky-tabs pattern as compact, with
    // the standard header replacing the compact one.
    return NestedScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      headerSliverBuilder: (ctx, _) => [
        SliverToBoxAdapter(
          child: _buildStandardHeader(
            context,
            isDark,
            detail,
            ref,
            myId,
            isAdmin,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBarDelegate(
            isDark: isDark,
            child: _buildTabs(context, isDark, tab, ref),
          ),
        ),
      ],
      body: _buildTabBody(context, ref, isDark, tab, detail, myId),
    );
  }

  Widget _buildLargeLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
    String? myId,
    bool isAdmin,
  ) {
    // Large: >1100px - generous spacing (32-48px), sidebar + content layout
    return Row(
      children: [
        // Left sidebar - Group info and members (32% width)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLargeHeader(context, isDark, detail),
                  const SizedBox(height: 32),
                  _buildMembersSection(
                    context,
                    isDark,
                    detail,
                    ref,
                    myId,
                    isAdmin,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right content area - Tabs + Expenses/Balances (68% width)
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              border: Border(
                left: BorderSide(color: AppColors.divider(isDark), width: 1),
              ),
            ),
            child: Column(
              children: [
                _buildTabs(context, isDark, tab, ref),
                // Hairline divider between tabs and content panel — matches
                // the compact/standard layouts' sticky bar separator.
                Container(
                  height: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _buildTabBody(context, ref, isDark, tab, detail, myId),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Compact header: <600px — hero gradient card + members strip
  Widget _buildCompactHeader(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    WidgetRef ref,
    String? myId,
    bool isAdmin,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(detail: detail),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'MEMBERS · ${detail.members.length}',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      fontSize: 11,
                    ),
                  ),
                ),
                _AddMemberButton(onTap: () => _showInviteDialog(context, ref)),
              ],
            ),
          ),
          _buildMembersList(context, isDark, detail, ref, myId, isAdmin),
        ],
      ),
    );
  }

  // Standard header: 600-1100px - improved spacing (24-32px)
  Widget _buildStandardHeader(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    WidgetRef ref,
    String? myId,
    bool isAdmin,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          bottom: BorderSide(color: AppColors.divider(isDark), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group title with cover image (or emoji fallback)
          Row(
            children: [
              GroupCoverThumb(
                coverImageBase64: detail.group.coverImageBase64,
                coverEmoji: detail.group.coverEmoji,
                size: 52,
                borderRadius: 14,
                emojiFontSize: 32,
                fallbackIconColor: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  detail.group.name,
                  style: AppTextStyles.headline2(isDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Statistics in a spacious row
          Row(
            children: [
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Total',
                  CurrencyFormatter.format(detail.totalExpense),
                ),
              ),
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Members',
                  '${detail.members.length}',
                ),
              ),
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Expenses',
                  '${detail.expenses.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'MEMBERS · ${detail.members.length}',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    fontSize: 11,
                  ),
                ),
              ),
              _AddMemberButton(onTap: () => _showInviteDialog(context, ref)),
            ],
          ),
          const SizedBox(height: 12),
          // Members list
          _buildMembersList(context, isDark, detail, ref, myId, isAdmin),
        ],
      ),
    );
  }

  // Large header: >1100px - generous spacing (32-48px)
  Widget _buildLargeHeader(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group title with large cover image (or emoji fallback)
        Row(
          children: [
            GroupCoverThumb(
              coverImageBase64: detail.group.coverImageBase64,
              coverEmoji: detail.group.coverEmoji,
              size: 64,
              borderRadius: 16,
              emojiFontSize: 42,
              fallbackIconColor: AppColors.textSecondary(isDark),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.group.name,
                    style: AppTextStyles.headline1(isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Statistics cards stacked vertically for desktop
        _buildLargeStatisticCard(
          context,
          isDark,
          'Total Amount',
          CurrencyFormatter.format(detail.totalExpense),
          Icons.account_balance_wallet_rounded,
          AppColors.brand,
        ),
        const SizedBox(height: 12),
        _buildLargeStatisticCard(
          context,
          isDark,
          'Total Members',
          '${detail.members.length}',
          Icons.people_rounded,
          AppColors.brand,
        ),
        const SizedBox(height: 12),
        _buildLargeStatisticCard(
          context,
          isDark,
          'Total Expenses',
          '${detail.expenses.length}',
          Icons.receipt_long_rounded,
          AppColors.success,
        ),
      ],
    );
  }

  // Desktop-style statistics card with icon
  Widget _buildLargeStatisticCard(
    BuildContext context,
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption(isDark)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.headline3(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact statistic for mobile (reduced font size)
  Widget _buildCompactStatistic(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(isDark).copyWith(fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.body2(
            isDark,
          ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Standard statistic for tablet/desktop
  Widget _buildStatistic(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption(isDark)),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.headline3(
            isDark,
          ).copyWith(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ],
    );
  }

  // Responsive members list - horizontal scroll for compact/standard, grid for large.
  //
  // Auth state (myId, isAdmin) is hoisted from the screen-level build via the
  // signature so this method doesn't open a second authProvider subscription
  // — every auth change rebuilds the whole tree once, not per-section.
  Widget _buildMembersList(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    WidgetRef ref,
    String? myId,
    bool isAdmin,
  ) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: detail.members.length,
        itemBuilder: (context, index) {
          final member = detail.members[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () => _showMemberActionsSheet(
                context: context,
                ref: ref,
                member: member,
                isAdmin: isAdmin,
                isSelf: member.id == myId,
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Opacity(
                        opacity: member.isPlaceholder ? 0.5 : 1.0,
                        child: AvatarWidget(
                          imageUrl: member.avatarUrl,
                          name: member.name,
                          radius: 24,
                        ),
                      ),
                      if (member.isPlaceholder)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.background(isDark),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 56,
                    child: Text(
                      member.name.split(' ')[0],
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: member.isPlaceholder
                            ? AppColors.textSecondary(isDark)
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Members section for large layout - compact list display.
  // Same hoisting pattern as _buildMembersList.
  Widget _buildMembersSection(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    WidgetRef ref,
    String? myId,
    bool isAdmin,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Members (${detail.members.length})',
                style: AppTextStyles.headline3(isDark),
              ),
            ),
            _AddMemberButton(onTap: () => _showInviteDialog(context, ref)),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: detail.members.length,
          itemBuilder: (context, index) {
            final member = detail.members[index];
            final isSelf = member.id == myId;
            final canRemove = isAdmin && !isSelf;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showMemberActionsSheet(
                    context: context,
                    ref: ref,
                    member: member,
                    isAdmin: isAdmin,
                    isSelf: isSelf,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.divider(isDark),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        AvatarWidget(
                          imageUrl: member.avatarUrl,
                          name: member.name,
                          radius: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: AppTextStyles.body2(isDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                member.email.isEmpty
                                    ? 'No email'
                                    : member.email,
                                style: AppTextStyles.caption(isDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (canRemove)
                          IconButton(
                            tooltip: 'Remove from group',
                            icon: Icon(
                              Icons.person_remove_outlined,
                              color: AppColors.errorText(isDark),
                            ),
                            onPressed: () =>
                                _confirmRemoveMember(context, ref, member),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabs(
    BuildContext context,
    bool isDark,
    GroupTab tab,
    WidgetRef ref,
  ) {
    // Watch the provider exactly once and reuse the AsyncValue, avoiding
    // a second listener subscription per build (and a redundant rebuild).
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final detail = detailAsync.value;
    final myId = ref.watch(myIdProvider);

    // The Balances badge previously showed member count, which read as
    // "2 outstanding balances" on a brand-new group with zero expenses.
    // Show the count of *active pairwise debts* (`|net| > 0.01`) instead —
    // matches what the Balances tab actually renders.
    int? balancesCount;
    if (detail != null && myId != null) {
      final pair = _pairwiseDebts(myId: myId, detail: detail);
      balancesCount = pair.values.where((v) => v.abs() > 0.01).length;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _TabButton(
              label: 'Expenses',
              icon: Icons.receipt_long_rounded,
              count: detail?.expenses.length,
              selected: tab == GroupTab.expenses,
              isDark: isDark,
              onTap: () {
                if (tab != GroupTab.expenses) {
                  HapticService.instance.selection();
                  ref.read(groupTabProvider.notifier).state = GroupTab.expenses;
                }
              },
            ),
            const SizedBox(width: 6),
            _TabButton(
              label: 'Balances',
              icon: Icons.balance_rounded,
              count: balancesCount,
              selected: tab == GroupTab.balances,
              isDark: isDark,
              onTap: () {
                if (tab != GroupTab.balances) {
                  HapticService.instance.selection();
                  ref.read(groupTabProvider.notifier).state = GroupTab.balances;
                }
              },
            ),
            const SizedBox(width: 6),
            _TabButton(
              label: 'Activity',
              icon: Icons.history_rounded,
              count: detail == null
                  ? null
                  : detail.expenses.length + detail.settlements.length,
              selected: tab == GroupTab.activity,
              isDark: isDark,
              onTap: () {
                if (tab != GroupTab.activity) {
                  HapticService.instance.selection();
                  ref.read(groupTabProvider.notifier).state = GroupTab.activity;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesList(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
  ) {
    if (detail.expenses.isEmpty) {
      return EmptyStateWidget.noExpenses();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final verticalSpacing = isCompact ? 8.0 : 12.0;

    // Standalone-scrollable so it can act as the body of NestedScrollView
    // (the outer header dismisses when the user scrolls this list).
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: detail.expenses.length,
      itemBuilder: (context, index) {
        final expense = detail.expenses[index];
        return Padding(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: verticalSpacing,
          ),
          child: Semantics(
            button: true,
            label: 'Expense - ${expense.title} for ₹${expense.amount}',
            child: ExpenseCard(
              expense: expense,
              onTap: () {
                context.push('/expense/${expense.id}');
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    GroupDetail detail,
    String? myId,
  ) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final pad = isCompact ? 16.0 : 24.0;

    // What I've already got in pending (unconfirmed) settlements to each
    // person — so Settle Up only asks for the not-yet-in-flight remainder.
    final pendingOut = myId == null
        ? const <String, double>{}
        : computePendingOutgoing(myId: myId, settlements: detail.settlements);

    final cards = myId == null
        ? const <BalanceCardData>[]
        : _balanceCardData(myId: myId, detail: detail, pendingOut: pendingOut);

    // Net pairwise balance with each person — used to gate the Settle Up /
    // Remind buttons on the log rows. pair[id] > 0 ⇒ I owe them; < 0 ⇒ they
    // owe me; ~0 ⇒ settled (so no button — this is what "disables Settle Up
    // once everything's settled" rather than reacting to a single expense).
    final pair = myId == null
        ? const <String, double>{}
        : _pairwiseDebts(myId: myId, detail: detail);

    // Per-split log entries, computed once and rendered lazily below.
    final logEntries = buildSplitLogEntries(
      expenses: detail.expenses,
      currentUserId: myId,
      memberById: {for (final m in detail.members) m.id: m},
    );

    // CustomScrollView so the (potentially long) per-split log builds lazily
    // via a SliverList.builder instead of all at once.
    // A single ListView.builder — the same reliable NestedScrollView body the
    // Expenses tab uses. Index 0 is the settlements + balance cards + the
    // "Expense log" header; indices 1.. are the lazily-built per-split log
    // rows. (A CustomScrollView here failed to scroll / show the log in
    // release builds.)
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: logEntries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PendingIncomingSettlementsSection(groupId: groupId),
              _PendingOutgoingSettlementsSection(groupId: groupId),
              if (cards.isEmpty)
                _buildAllSettledCard(isDark, pad)
              else ...[
                _buildSectionHeader('Balances', isDark: isDark, padding: pad),
                const SizedBox(height: 8),
                BalanceSummaryCards(
                  entries: cards,
                  horizontalPadding: pad,
                  onTap: (entry) {
                    // No drill-in for your own card or a settled member.
                    if (entry.isMe || entry.settled) return;
                    context.push(
                      '/home/groups/$groupId/settlements-with/${entry.member.id}',
                    );
                  },
                  onSettle: (entry) => context.push(
                    '/settle/${entry.member.id}?groupId=$groupId'
                    '&amount=${entry.settleAmount.toStringAsFixed(2)}',
                  ),
                  onRemind: (entry) =>
                      _sendReminder(context, ref, entry.member),
                ),
              ],
              if (logEntries.isNotEmpty) ...[
                const SizedBox(height: 22),
                _buildSectionHeader(
                  'Expense log',
                  isDark: isDark,
                  padding: pad,
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        }

        final entry = logEntries[index - 1];
        // Gate the action by the NET balance with this person, not the single
        // expense's share. Once the net is settled, neither button shows.
        final net = pair[entry.personId] ?? 0;
        final iOweNet = net > 0.01; // I still owe them overall
        final theyOweMeNet = net < -0.01; // they still owe me overall
        // Guard the clamp: clamp(0, negative) throws when net <= 0.
        final pendOut = pendingOut[entry.personId] ?? 0;
        final toSettle = net > 0
            ? (net - pendOut).clamp(0, net).toDouble()
            : 0.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
          child: SplitLogRow(
            entry: entry,
            onTap: () => context.push('/expense/${entry.expense.id}'),
            onRemind: (entry.theyOweMe && theyOweMeNet)
                ? () => _sendReminder(
                    context,
                    ref,
                    detail.members.firstWhere(
                      (m) => m.id == entry.personId,
                      orElse: () => UserModel(
                        id: entry.personId,
                        name: entry.personName,
                        email: '',
                        phone: '',
                        createdAt: DateTime.now(),
                      ),
                    ),
                  )
                : null,
            onSettle: (!entry.theyOweMe && iOweNet && toSettle > 0.01)
                ? () => context.push(
                    '/settle/${entry.personId}?groupId=$groupId'
                    '&amount=${toSettle.toStringAsFixed(2)}',
                  )
                : null,
          ),
        );
      },
    );
  }

  /// Per-person net balances vs. the current user, sorted by magnitude
  /// (largest first) for the balance cards carousel.
  List<BalanceCardData> _balanceCardData({
    required String myId,
    required GroupDetail detail,
    Map<String, double> pendingOut = const {},
  }) {
    final pair = _pairwiseDebts(myId: myId, detail: detail);
    final cards = <BalanceCardData>[];

    // "You" card first — my net across the group (positive = I'm owed).
    final me = detail.members.firstWhereOrNull((m) => m.id == myId);
    if (me != null) {
      final sumIOwe = pair.values.fold<double>(0, (s, v) => s + v);
      final myNet = -sumIOwe; // >0 ⇒ others owe me overall
      cards.add(
        BalanceCardData(
          member: me,
          amount: myNet.abs(),
          iOweThem: myNet < 0,
          isMe: true,
          settled: myNet.abs() <= 0.01,
        ),
      );
    }

    // Every other member — including those who are settled up.
    final others = <BalanceCardData>[];
    for (final m in detail.members) {
      if (m.id == myId) continue;
      final v = pair[m.id] ?? 0;
      final iOwe = v > 0;
      // Only my outgoing pending matters for Settle Up.
      final pend = iOwe ? (pendingOut[m.id] ?? 0).clamp(0, v).toDouble() : 0.0;
      final settle = iOwe ? (v - pend).clamp(0, v).toDouble() : 0.0;
      others.add(
        BalanceCardData(
          member: m,
          amount: v.abs(),
          iOweThem: iOwe,
          settled: v.abs() <= 0.01,
          settleAmount: settle,
          pendingAmount: pend,
        ),
      );
    }
    // Outstanding balances first (largest first), settled members last.
    others.sort((a, b) {
      if (a.settled != b.settled) return a.settled ? 1 : -1;
      return b.amount.compareTo(a.amount);
    });

    cards.addAll(others);
    return cards;
  }

  Widget _buildAllSettledCard(bool isDark, double padding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark), width: 1),
        ),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              'All settled up',
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'No one owes anyone in this group.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  /// Pairwise debts from the current user's perspective. Delegates to the
  /// shared [computePairwiseDebts] so the screen, the log rows and the
  /// expense-detail buttons all agree (and match the backend, which counts
  /// only confirmed settlements).
  Map<String, double> _pairwiseDebts({
    required String myId,
    required GroupDetail detail,
  }) {
    return computePairwiseDebts(
      myId: myId,
      expenses: detail.expenses,
      settlements: detail.settlements,
    );
  }

  Widget _buildBalancesList(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    String? myId,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final verticalSpacing = isCompact ? 8.0 : 12.0;

    if (myId == null) return const SizedBox.shrink();
    final pair = _pairwiseDebts(myId: myId, detail: detail);
    final iOwe = pair.entries.where((e) => e.value > 0.01).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final owedToMe = pair.entries.where((e) => e.value < -0.01).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (iOwe.isEmpty && owedToMe.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 32,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark), width: 1),
          ),
          child: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                'All settled up',
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'No one owes anyone in this group.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (iOwe.isNotEmpty) ...[
          _buildSectionHeader(
            'You owe',
            isDark: isDark,
            padding: horizontalPadding,
          ),
          ...iOwe.map(
            (e) => _buildPairRow(
              context: context,
              isDark: isDark,
              detail: detail,
              otherId: e.key,
              amount: e.value, // positive
              iOweThem: true,
              horizontalPadding: horizontalPadding,
              verticalSpacing: verticalSpacing,
            ),
          ),
        ],
        if (owedToMe.isNotEmpty) ...[
          _buildSectionHeader(
            'Owed to you',
            isDark: isDark,
            padding: horizontalPadding,
          ),
          ...owedToMe.map(
            (e) => _buildPairRow(
              context: context,
              isDark: isDark,
              detail: detail,
              otherId: e.key,
              amount: e.value.abs(),
              iOweThem: false,
              horizontalPadding: horizontalPadding,
              verticalSpacing: verticalSpacing,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String label, {
    required bool isDark,
    required double padding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 4, padding, 8),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildPairRow({
    required BuildContext context,
    required bool isDark,
    required GroupDetail detail,
    required String otherId,
    required double amount,
    required bool iOweThem,
    required double horizontalPadding,
    required double verticalSpacing,
  }) {
    final member = detail.members.firstWhereOrNull((m) => m.id == otherId);
    if (member == null) return const SizedBox.shrink();

    final accent = iOweThem ? AppColors.warning : AppColors.success;
    final caption = iOweThem ? 'You owe' : 'Owes you';

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: verticalSpacing,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(
            '/home/groups/$groupId/settlements-with/${member.id}',
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(isDark), width: 1),
            ),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: member.avatarUrl,
                  name: member.name,
                  radius: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: AppTextStyles.body2(
                          isDark,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(caption, style: AppTextStyles.caption(isDark)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        CurrencyFormatter.format(amount),
                        style: AppTextStyles.body2(
                          isDark,
                        ).copyWith(color: accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (iOweThem) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () {
                          context.push(
                            '/settle/${member.id}?groupId=$groupId&amount=${amount.toStringAsFixed(2)}',
                          );
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 28),
                        ),
                        child: const Text('Settle Up'),
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Consumer(
                        builder: (context, ref, _) => TextButton.icon(
                          onPressed: () => _sendReminder(context, ref, member),
                          icon: Icon(
                            Icons.notifications_active_rounded,
                            size: 14,
                            color: AppColors.brand,
                          ),
                          label: Text(
                            'Remind',
                            style: TextStyle(color: AppColors.brand),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 28),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailTopBar({
    required this.isDark,
    required this.onClose,
    required this.onAddMember,
    required this.onEditGroup,
    required this.onLeaveGroup,
    required this.onDeleteGroup,
    required this.onExportGroup,
    required this.isAdmin,
    required this.canManage,
  });

  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onAddMember;

  /// Set when the admin can edit the group. Null disables the option
  /// (e.g. while the detail is still loading).
  final VoidCallback? onEditGroup;
  final VoidCallback onLeaveGroup;
  final VoidCallback onDeleteGroup;

  /// Set when the group is loaded so the user can request a .xlsx ledger.
  /// Null hides the option while still loading.
  final VoidCallback? onExportGroup;

  /// True when the signed-in user is the group's admin/creator.
  final bool isAdmin;

  /// False while the group detail is still loading — hides Leave/Delete to
  /// avoid acting on stale state.
  final bool canManage;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background(isDark),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                isDark: isDark,
                onTap: onClose,
                label: 'Back',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Group',
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const DonateHeartButton(),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'More options',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: PopupMenuButton<String>(
                    color: AppColors.cardBg(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.divider(isDark)),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit_group':
                          onEditGroup?.call();
                          break;
                        case 'add_member':
                          onAddMember();
                          break;
                        case 'export':
                          onExportGroup?.call();
                          break;
                        case 'leave':
                          onLeaveGroup();
                          break;
                        case 'delete':
                          onDeleteGroup();
                          break;
                      }
                    },
                    icon: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    itemBuilder: (_) => [
                      // Edit group: admin only. Lets them change name / cover photo.
                      if (canManage && isAdmin && onEditGroup != null)
                        PopupMenuItem(
                          value: 'edit_group',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.textPrimary(isDark),
                              ),
                              const SizedBox(width: 10),
                              const Text('Edit group'),
                            ],
                          ),
                        ),
                      // Add member: also exposed as a "+ Add" pill next to the
                      // MEMBERS header — kept here for discoverability.
                      PopupMenuItem(
                        value: 'add_member',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add_rounded,
                              size: 18,
                              color: AppColors.textPrimary(isDark),
                            ),
                            const SizedBox(width: 10),
                            const Text('Add member'),
                          ],
                        ),
                      ),
                      // Leave group: members only. The admin can't leave
                      // their own group from here — they have to delete it
                      // (or transfer admin first, in a future change).
                      if (canManage && !isAdmin)
                        PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 10),
                              const Text('Leave group'),
                            ],
                          ),
                        ),
                      // Export to Excel: any member can export the ledger.
                      // Placed right before Delete so admins still see Delete
                      // as the final destructive action.
                      if (onExportGroup != null)
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(
                                Icons.file_download_outlined,
                                size: 18,
                                color: AppColors.textPrimary(isDark),
                              ),
                              const SizedBox(width: 10),
                              const Text('Export to Excel'),
                            ],
                          ),
                        ),
                      // Delete group: admin only.
                      if (canManage && isAdmin)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.errorText(isDark),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Delete group',
                                style: TextStyle(
                                  color: AppColors.errorText(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Icon(icon, size: 18, color: AppColors.textPrimary(isDark)),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.detail});
  final GroupDetail detail;

  static const String _defaultPeopleEmoji = '👥';

  @override
  Widget build(BuildContext context) {
    final total = CurrencyFormatter.format(detail.totalExpense, currency: '₹');
    final memberCount = detail.members.length;
    final expenseCount = detail.expenses.length;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.tealLight, AppColors.tealDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealDark.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -30,
              right: -20,
              child: _Orb(size: 140, opacity: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: GroupCoverThumb(
                          coverImageBase64: detail.group.coverImageBase64,
                          coverEmoji: detail.group.coverEmoji,
                          size: 48,
                          borderRadius: 14,
                          emojiFontSize: 24,
                          fallbackIconColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'GROUP',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail.group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(label: 'TOTAL SPENT', value: total),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      Expanded(
                        child: _HeroStat(
                          label: 'MEMBERS',
                          value: '$memberCount',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      Expanded(
                        child: _HeroStat(
                          label: 'EXPENSES',
                          value: '$expenseCount',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped tab chip. Selected state: filled with brand teal + white
/// content. Unselected: transparent with muted text and a 60%-opacity
/// icon — matches the shadcn / Radix "rounded-full primary" tab pattern.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? Colors.white : AppColors.textSecondary(isDark);
    final Color iconColor = selected
        ? Colors.white
        : AppColors.textSecondary(isDark).withValues(alpha: 0.7);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.tealDark : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: selected
                  ? null
                  : Border.all(color: AppColors.divider(isDark)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.body2(isDark).copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : AppColors.tealDark.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.tealDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pending settlements where the current user is the recipient.
/// Shown above the balances list; tap Confirm to flip status pending → completed.
class _PendingIncomingSettlementsSection extends ConsumerWidget {
  const _PendingIncomingSettlementsSection({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(pendingIncomingSettlementsProvider(groupId));
    final items = asyncPending.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.handshake_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Confirm payments received',
                  style: AppTextStyles.body2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in items)
              _PendingSettlementTile(
                settlement: s,
                groupId: groupId,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingSettlementTile extends ConsumerStatefulWidget {
  const _PendingSettlementTile({
    required this.settlement,
    required this.groupId,
    required this.isDark,
  });

  final dynamic settlement; // SettlementModel
  final String groupId;
  final bool isDark;

  @override
  ConsumerState<_PendingSettlementTile> createState() =>
      _PendingSettlementTileState();
}

class _PendingSettlementTileState
    extends ConsumerState<_PendingSettlementTile> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return; // anti-double-tap (rebuild can momentarily reset _busy)
    setState(() => _busy = true);
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .confirm(widget.settlement.id as String);
      ref.invalidate(pendingIncomingSettlementsProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settlement confirmed')));
    } catch (e) {
      // "Settlement already confirmed / not found" means our intent already
      // succeeded — usually a duplicate tap that slipped past the rebuild.
      // Treat as success: refresh providers, no scary snackbar.
      final msg = e.toString().toLowerCase();
      final benign =
          msg.contains('already confirmed') || msg.contains('not found');
      if (benign) {
        ref.invalidate(pendingIncomingSettlementsProvider(widget.groupId));
        ref.invalidate(groupDetailProvider(widget.groupId));
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not confirm: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final fromName = (s.fromUser.name as String).isEmpty
        ? 'Someone'
        : s.fromUser.name as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$fromName paid you ${CurrencyFormatter.format(s.amount as double)}',
              style: AppTextStyles.body2(widget.isDark),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// Pending settlements the current user *sent* (awaiting recipient confirmation).
/// Lets the sender withdraw via DELETE /settlements/:id.
class _PendingOutgoingSettlementsSection extends ConsumerWidget {
  const _PendingOutgoingSettlementsSection({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(pendingOutgoingSettlementsProvider(groupId));
    final items = asyncPending.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_send_rounded,
                  size: 18,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 8),
                Text(
                  'Awaiting confirmation',
                  style: AppTextStyles.body2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in items)
              _OutgoingSettlementTile(
                settlement: s,
                groupId: groupId,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingSettlementTile extends ConsumerStatefulWidget {
  const _OutgoingSettlementTile({
    required this.settlement,
    required this.groupId,
    required this.isDark,
  });

  final dynamic settlement; // SettlementModel
  final String groupId;
  final bool isDark;

  @override
  ConsumerState<_OutgoingSettlementTile> createState() =>
      _OutgoingSettlementTileState();
}

class _OutgoingSettlementTileState
    extends ConsumerState<_OutgoingSettlementTile> {
  bool _busy = false;

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this pending settlement?'),
        content: const Text(
          'The recipient will no longer see this payment as pending. '
          'You can record it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .delete(widget.settlement.id as String);
      ref.invalidate(pendingOutgoingSettlementsProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settlement cancelled')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final toName = (s.toUser.name as String).isEmpty
        ? 'Someone'
        : s.toUser.name as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'You sent $toName ${CurrencyFormatter.format(s.amount as double)}',
              style: AppTextStyles.body2(widget.isDark),
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorText(widget.isDark),
              side: BorderSide(color: AppColors.errorText(widget.isDark)),
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Small pill-style "+ Add" button that lives next to the Members header.
/// Replaces the (removed) "Add member" item from the 3-dot menu.
class _AddMemberButton extends StatelessWidget {
  const _AddMemberButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.brand.withValues(alpha: isDark ? 0.18 : 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: AppColors.brand),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700, color: AppColors.brand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailInviteSheet extends StatefulWidget {
  const _EmailInviteSheet({required this.memberName, required this.isDark});

  final String memberName;
  final bool isDark;

  @override
  State<_EmailInviteSheet> createState() => _EmailInviteSheetState();
}

class _EmailInviteSheetState extends State<_EmailInviteSheet> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_ctrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider(widget.isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Invite ${widget.memberName}',
            style: AppTextStyles.body1(
              widget.isDark,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'name@example.com',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Email is required';
                if (!s.contains('@') || !s.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Send Invite'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
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
