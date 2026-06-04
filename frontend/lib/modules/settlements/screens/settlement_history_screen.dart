import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_detail_provider.dart';

/// History of settlements between the current user and one other member,
/// scoped to a single group. Lists every transfer (pending, completed,
/// failed) with totals and a net-balance summary, grouped by month.
class SettlementHistoryScreen extends ConsumerWidget {
  const SettlementHistoryScreen({
    super.key,
    required this.groupId,
    required this.otherUserId,
  });

  final String groupId;
  final String otherUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final me = ref.watch(authProvider).user;
    final detailAsync = ref.watch(groupDetailProvider(groupId));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        onBack: () => context.canPop() ? context.pop() : null,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: screenWidth < 1100 ? 640 : 760),
            child: detailAsync.when(
              loading: () => const _LoadingState(),
              error: (e, _) => _ErrorState(
                isDark: isDark,
                onRetry: () async {
                  ref.invalidate(groupDetailProvider(groupId));
                  await ref.read(groupDetailProvider(groupId).future);
                },
              ),
              data: (detail) {
                final other = detail.members
                    .firstWhereOrNull((m) => m.id == otherUserId);
                final pair = me == null
                    ? const <SettlementModel>[]
                    : (detail.settlements.where((s) {
                        return (s.fromUser.id == me.id &&
                                s.toUser.id == otherUserId) ||
                            (s.fromUser.id == otherUserId &&
                                s.toUser.id == me.id);
                      }).toList()
                      ..sort((a, b) => b.date.compareTo(a.date)));

                return RefreshIndicator(
                  color: AppColors.tealDark,
                  onRefresh: () async {
                    ref.invalidate(groupDetailProvider(groupId));
                    await ref.read(groupDetailProvider(groupId).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _Hero(
                        isDark: isDark,
                        me: me,
                        other: other,
                        groupName: detail.group.name,
                        settlements: pair,
                      ),
                      const SizedBox(height: 20),
                      if (pair.isEmpty)
                        _EmptyState(
                          isDark: isDark,
                          otherName: other?.name ?? 'them',
                        )
                      else
                        ..._buildGroupedTiles(pair, me!.id, isDark),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Groups settlements by "MMM yyyy" header for easier scanning.
  List<Widget> _buildGroupedTiles(
    List<SettlementModel> pair,
    String myId,
    bool isDark,
  ) {
    final groups = <String, List<SettlementModel>>{};
    for (final s in pair) {
      final key = DateFormat('MMM yyyy').format(s.date).toUpperCase();
      groups.putIfAbsent(key, () => []).add(s);
    }

    final tiles = <Widget>[];
    final keys = groups.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final k = keys[i];
      final items = groups[k]!;
      if (i > 0) tiles.add(const SizedBox(height: 18));
      tiles.add(_SectionLabel(text: k, isDark: isDark));
      tiles.add(const SizedBox(height: 8));
      tiles.add(
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            children: [
              for (int j = 0; j < items.length; j++) ...[
                _SettlementRow(
                  settlement: items[j],
                  myId: myId,
                  isDark: isDark,
                ),
                if (j < items.length - 1)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    height: 1,
                    color:
                        AppColors.divider(isDark).withValues(alpha: 0.6),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return tiles;
  }
}

// --------------------------------------------------------------------------
// Top bar
// --------------------------------------------------------------------------

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.isDark, required this.onBack});
  final bool isDark;
  final VoidCallback? onBack;

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
              Semantics(
                button: true,
                label: 'Back',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onBack,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(isDark),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Settlement history',
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Hero — two avatars + names + group + net summary
// --------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({
    required this.isDark,
    required this.me,
    required this.other,
    required this.groupName,
    required this.settlements,
  });

  final bool isDark;
  final UserModel? me;
  final UserModel? other;
  final String groupName;
  final List<SettlementModel> settlements;

  @override
  Widget build(BuildContext context) {
    // Compute totals (only confirmed settlements count toward the net).
    double iPaid = 0;
    double theyPaid = 0;
    String currency = '';
    int confirmed = 0;
    int pending = 0;
    for (final s in settlements) {
      if (currency.isEmpty) currency = s.currency;
      if (s.status == SettlementStatus.completed) {
        confirmed++;
        if (s.fromUser.id == me?.id) {
          iPaid += s.amount;
        } else {
          theyPaid += s.amount;
        }
      } else if (s.status == SettlementStatus.pending) {
        pending++;
      }
    }
    final net = iPaid - theyPaid;
    final hasNet = net.abs() > 0.005;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          // Avatars + arrow icon between them
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AvatarBlock(
                name: me?.name ?? 'You',
                subtitle: 'You',
                imageUrl: me?.avatarUrl,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(width: 8),
              _AvatarBlock(
                name: other?.name ?? 'Member',
                subtitle: other?.name ?? 'Member',
                imageUrl: other?.avatarUrl,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Group + count line
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_outlined,
                size: 13,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  groupName,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(isDark),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${settlements.length} ${settlements.length == 1 ? 'settlement' : 'settlements'}',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (settlements.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: AppColors.divider(isDark).withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            // Totals grid
            Row(
              children: [
                Expanded(
                  child: _TotalBlock(
                    isDark: isDark,
                    label: 'You paid',
                    amount: iPaid,
                    currency: currency,
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.warning,
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
                Expanded(
                  child: _TotalBlock(
                    isDark: isDark,
                    label: 'They paid',
                    amount: theyPaid,
                    currency: currency,
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            if (hasNet || pending > 0) ...[
              const SizedBox(height: 12),
              _NetSummary(
                isDark: isDark,
                net: net,
                currency: currency,
                pending: pending,
                confirmed: confirmed,
                otherName: other?.name ?? 'them',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.isDark,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          AvatarWidget(
            imageUrl: imageUrl,
            name: name,
            radius: 26,
            borderWidth: 2,
            borderColor: AppColors.divider(isDark),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.body2(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({
    required this.isDark,
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
  });

  final bool isDark;
  final String label;
  final double amount;
  final String currency;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount == 0
              ? '—'
              : CurrencyFormatter.format(amount, currency: currency),
          style: AppTextStyles.body1(isDark).copyWith(
            color: amount == 0 ? AppColors.textSecondary(isDark) : color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _NetSummary extends StatelessWidget {
  const _NetSummary({
    required this.isDark,
    required this.net,
    required this.currency,
    required this.pending,
    required this.confirmed,
    required this.otherName,
  });

  final bool isDark;
  final double net;
  final String currency;
  final int pending;
  final int confirmed;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    final hasNet = net.abs() > 0.005;
    final youAhead = net > 0; // you paid more than they did
    String label;
    Color accent;
    IconData icon;
    if (!hasNet && confirmed > 0) {
      label = 'All settled with $otherName';
      accent = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (youAhead) {
      label =
          'Net: $otherName owes you ${CurrencyFormatter.format(net, currency: currency)}';
      accent = AppColors.success;
      icon = Icons.trending_up_rounded;
    } else {
      label =
          'Net: You owe $otherName ${CurrencyFormatter.format(net.abs(), currency: currency)}';
      accent = AppColors.warning;
      icon = Icons.trending_down_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption(isDark).copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (pending > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '$pending pending',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Section label (uppercase overline)
// --------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Settlement row
// --------------------------------------------------------------------------

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.settlement,
    required this.myId,
    required this.isDark,
  });

  final SettlementModel settlement;
  final String myId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final iPaid = settlement.fromUser.id == myId;
    final counterpart =
        iPaid ? settlement.toUser.name : settlement.fromUser.name;
    final accent = iPaid ? AppColors.warning : AppColors.success;
    final icon = iPaid
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final headline =
        iPaid ? 'You paid $counterpart' : '$counterpart paid you';
    final note = settlement.note?.trim();
    final isMuted = settlement.status != SettlementStatus.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isMuted
                              ? AppColors.textSecondary(isDark)
                              : AppColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(
                        settlement.amount,
                        currency: settlement.currency,
                      ),
                      style: AppTextStyles.body1(isDark).copyWith(
                        color: isMuted
                            ? AppColors.textSecondary(isDark)
                            : accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy · h:mm a')
                          .format(settlement.date),
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      status: settlement.status,
                      isDark: isDark,
                    ),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.divider(isDark),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 11,
                          color: AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            note,
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.textPrimary(isDark),
                              fontSize: 11.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isDark});
  final SettlementStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    IconData icon;
    switch (status) {
      case SettlementStatus.completed:
        label = 'Confirmed';
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case SettlementStatus.pending:
        label = 'Pending';
        color = AppColors.warning;
        icon = Icons.schedule_rounded;
        break;
      case SettlementStatus.failed:
        label = 'Failed';
        color = AppColors.errorText(isDark);
        icon = Icons.error_outline_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.caption(isDark).copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Empty / Loading / Error states
// --------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark, required this.otherName});
  final bool isDark;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 36,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No settlements yet',
            style: AppTextStyles.body1(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When you settle up with $otherName, the history will appear here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 90,
          height: 11,
          margin: const EdgeInsets.only(left: 4, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.isDark, required this.onRetry});
  final bool isDark;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      children: [
        Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 14),
            Text(
              "Couldn't load settlement history",
              textAlign: TextAlign.center,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => onRetry(),
              child: Text(
                'Retry',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
