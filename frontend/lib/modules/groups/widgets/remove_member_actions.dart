import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/user_model.dart';
import '../../../core/services/haptic_service.dart';
import '../state/group_balance_helpers.dart';
import '../state/group_detail_provider.dart';
import '../state/groups_provider.dart';

Future<void> confirmRemoveMember(
  String groupId,
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
      : groupPairwiseDebts(myId: member.id, detail: detail);
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
    final proceed = await showWriteOffDialog(context, member, info);
    if (proceed != true || !context.mounted) return;
    HapticService.instance.destructive();
    await performRemoveMember(
      groupId,
      context,
      ref,
      member,
      acknowledged: true,
    );
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
  await performRemoveMember(groupId, context, ref, member, acknowledged: false);
}

/// Performs the actual `removeMember` call. On the first attempt
/// `acknowledged` is false; if the backend rejects with the
/// `UNSETTLED_BALANCES` code we surface a write-off dialog that
/// recurses back here with `acknowledged: true`.
Future<void> performRemoveMember(
  String groupId,
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
      final proceed = await showWriteOffDialog(context, member, info);
      if (proceed == true && context.mounted) {
        HapticService.instance.destructive();
        await performRemoveMember(
          groupId,
          context,
          ref,
          member,
          acknowledged: true,
        );
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
Future<bool?> showWriteOffDialog(
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

Widget _writeOffRow(PairwiseDebt p, String Function(double) fmt, bool isDark) {
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
