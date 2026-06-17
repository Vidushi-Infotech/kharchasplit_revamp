import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert' show base64Decode;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/push_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/expense_model.dart';
import '../../../models/settlement_model.dart';
import '../../../models/split_model.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_activity_provider.dart';
import '../state/group_detail_provider.dart';

/// 3rd tab in the group detail screen — chronological feed of expenses
/// and settlements with expand-in-place detail, date grouping, filter
/// chips, search, pull-to-refresh, and push-driven auto-refresh.
class GroupActivityTab extends ConsumerStatefulWidget {
  const GroupActivityTab({
    super.key,
    required this.groupId,
    this.onRefresh,
  });

  final String groupId;

  /// Pull-to-refresh callback. When the parent (Group Detail screen)
  /// supplies one, we delegate to it so a single swipe reloads ALL three
  /// tabs' data — not just the activity feed. Falls back to a local
  /// invalidate when null so the widget still works standalone.
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<GroupActivityTab> createState() => _GroupActivityTabState();
}

class _GroupActivityTabState extends ConsumerState<GroupActivityTab> {
  final Set<String> _expanded = <String>{};
  late TextEditingController _searchController;
  StreamSubscription? _pushSub;

  static const _refreshOnPushTypes = <String>{
    'EXPENSE_ADDED',
    'EXPENSE_UPDATED',
    'EXPENSE_DELETED',
    'SETTLEMENT_CREATED',
    'SETTLEMENT_CONFIRMED',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(groupFeedSearchProvider),
    );

    // Push-driven auto-refresh. The backend includes `groupId` and `type`
    // in the FCM data payload for every group event; when an event for
    // *this* group arrives while the tab is mounted, invalidate the
    // group detail provider so the merged feed picks up the new row.
    if (PushService.isSupportedPlatform) {
      _pushSub =
          PushService.instance.onForegroundMessage.listen((message) {
        if (!mounted) return;
        final data = message.data;
        final type = (data['type'] ?? '').toString();
        final pushedGroupId = (data['groupId'] ?? '').toString();
        if (pushedGroupId != widget.groupId) return;
        if (!_refreshOnPushTypes.contains(type)) return;
        ref.invalidate(groupDetailProvider(widget.groupId));
      });
    }
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feedAsync = ref.watch(groupFeedProvider(widget.groupId));
    final myId = ref.watch(myIdProvider);

    // CustomScrollView so the inner list scroll coordinates with a parent
    // NestedScrollView (sticky tabs on the group detail screen). The
    // toolbar is its own sliver above the feed; it scrolls away with the
    // first few rows, leaving only the pinned tab bar at the top.
    return RefreshIndicator(
      onRefresh: () async {
        // Delegate to the parent screen when one is provided so the swipe
        // reloads every tab's data, not just the activity feed. Fall back
        // to a local invalidate so the widget still works standalone.
        if (widget.onRefresh != null) {
          await widget.onRefresh!();
          return;
        }
        HapticService.instance.thresholdCrossed();
        ref.invalidate(groupDetailProvider(widget.groupId));
        await ref.read(groupDetailProvider(widget.groupId).future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Toolbar(
              isDark: isDark,
              searchController: _searchController,
              onSearchChanged: (v) =>
                  ref.read(groupFeedSearchProvider.notifier).state = v,
            ),
          ),
          feedAsync.when(
            loading: () => SliverToBoxAdapter(
              child: _FeedSkeleton(isDark: isDark),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _FeedError(
                isDark: isDark,
                message: err.toString(),
                onRetry: () =>
                    ref.invalidate(groupDetailProvider(widget.groupId)),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FeedEmpty(
                    isDark: isDark,
                    showingFilter:
                        ref.read(groupFeedFilterProvider) != FeedFilter.all ||
                            ref
                                .read(groupFeedSearchProvider)
                                .trim()
                                .isNotEmpty,
                  ),
                );
              }
              return _buildSliverList(items, isDark, myId);
            },
          ),
        ],
      ),
    );
  }

  /// Flattens the date-grouped feed into a flat builder list and returns
  /// a [SliverPadding] containing a [SliverList] so the feed integrates
  /// with the parent [NestedScrollView] (sticky tabs on the group screen).
  Widget _buildSliverList(
    List<GroupFeedItem> items,
    bool isDark,
    String? myId,
  ) {
    final flat = <_FlatEntry>[];
    String? lastKey;
    for (final item in items) {
      final key = _dateKey(item.createdAt);
      if (key != lastKey) {
        flat.add(_HeaderEntry(_dateHeader(item.createdAt)));
        lastKey = key;
      }
      flat.add(_ItemEntry(item));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList.builder(
        itemCount: flat.length,
        itemBuilder: (_, i) {
          final entry = flat[i];
          if (entry is _HeaderEntry) {
            return Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6, left: 2),
              child: Text(
                entry.label,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontSize: 11,
                ),
              ),
            );
          }
          final feedItem = (entry as _ItemEntry).item;
          // RepaintBoundary scopes each card to its own raster layer —
          // expanding/collapsing one row only repaints THAT row, not the
          // whole visible portion of the feed. Critical for smooth
          // scrolling on long feeds when state on one card changes.
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: switch (feedItem) {
                ExpenseFeedItem(:final expense) => _ExpenseCard(
                    expense: expense,
                    isDark: isDark,
                    myId: myId,
                    isExpanded: _expanded.contains(feedItem.id),
                    onTap: () => _toggle(feedItem.id),
                  ),
                SettlementFeedItem(:final settlement) => _SettlementCard(
                    settlement: settlement,
                    isDark: isDark,
                    myId: myId,
                    isExpanded: _expanded.contains(feedItem.id),
                    onTap: () => _toggle(feedItem.id),
                  ),
              },
            ),
          );
        },
      ),
    );
  }

  void _toggle(String id) {
    HapticService.instance.tap();
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  // -- Date helpers --

  /// Stable bucket key (yyyy-mm-dd) used for change detection between
  /// adjacent rows.
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _dateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff > 1 && diff < 7) return DateFormat('EEEE').format(d).toUpperCase();
    if (that.year == today.year) {
      return DateFormat('MMM d').format(d).toUpperCase();
    }
    return DateFormat('MMM d, yyyy').format(d).toUpperCase();
  }
}

// ============================================================================
// Toolbar — filter chips + search bar
// ============================================================================

class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.isDark,
    required this.searchController,
    required this.onSearchChanged,
  });

  final bool isDark;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(groupFeedFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 32,
            child: Row(
              children: [
                for (final f in FeedFilter.values) ...[
                  _FilterChip(
                    label: _filterLabel(f),
                    selected: filter == f,
                    isDark: isDark,
                    onTap: () {
                      if (filter != f) {
                        HapticService.instance.selection();
                        ref.read(groupFeedFilterProvider.notifier).state = f;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Search bar
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: AppTextStyles.body2(isDark).copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search description, member, amount',
              hintStyle: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 14,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.cardBg(isDark),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.textSecondary(isDark),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: AppColors.textSecondary(isDark),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider(isDark)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.tealDark.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _filterLabel(FeedFilter f) {
    switch (f) {
      case FeedFilter.all:
        return 'All';
      case FeedFilter.expenses:
        return 'Expenses';
      case FeedFilter.settlements:
        return 'Settlements';
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.tealDark : AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected ? AppColors.tealDark : AppColors.divider(isDark),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2(isDark).copyWith(
            color: selected
                ? Colors.white
                : AppColors.textPrimary(isDark),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Expense card (collapsed + expanded states)
// ============================================================================

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.isDark,
    required this.myId,
    required this.isExpanded,
    required this.onTap,
  });

  final ExpenseModel expense;
  final bool isDark;
  final String? myId;
  final bool isExpanded;
  final VoidCallback onTap;

  bool get _ownedByMe => myId != null && expense.paidBy.id == myId;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(expense.category.colorHex) ??
        AppColors.tealDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
            // Subtle left bar for self-added expenses so the user
            // can scan the feed and spot what they added vs others.
            boxShadow: _ownedByMe
                ? [
                    BoxShadow(
                      color: AppColors.tealDark.withValues(alpha: 0.10),
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: const Offset(-3, 0),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _collapsedHeader(categoryColor),
              if (isExpanded) _expandedBody(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collapsedHeader(Color categoryColor) {
    final actor = _ownedByMe ? 'You' : expense.paidBy.name;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AvatarWidget(
            name: expense.paidBy.name,
            imageUrl: expense.paidBy.avatarUrl,
            radius: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: actor,
                        style: AppTextStyles.body2(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      TextSpan(
                        text: ' added ',
                        style: AppTextStyles.body2(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 13.5,
                        ),
                      ),
                      TextSpan(
                        text: expense.title,
                        style: AppTextStyles.body2(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      expense.category.icon,
                      size: 12,
                      color: categoryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expense.category.name,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      ' · ${DateFormat.jm().format(expense.date)}',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _money(expense.amount, expense.currency),
                style: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expandedBody(BuildContext context) {
    final totalSplits = expense.splits.length;
    final settledCount = expense.splits.where((s) => s.isSettled).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 18,
            thickness: 1,
            color: AppColors.divider(isDark).withValues(alpha: 0.5),
          ),
          _miniLabel('PAID BY'),
          const SizedBox(height: 6),
          _paidByRow(),
          const SizedBox(height: 14),
          _miniLabel(
            'SPLIT AMONG · $totalSplits · $settledCount/$totalSplits SETTLED',
          ),
          const SizedBox(height: 6),
          ...expense.splits.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _splitRow(s),
              )),
          if (expense.receiptBase64 != null &&
              expense.receiptBase64!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _miniLabel('RECEIPT'),
            const SizedBox(height: 6),
            _receiptThumb(expense.receiptBase64!),
          ],
          if (expense.notes != null && expense.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _miniLabel('NOTES'),
            const SizedBox(height: 6),
            Text(
              expense.notes!,
              style: AppTextStyles.body2(isDark).copyWith(
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.pushNamed('expense-detail', pathParameters: {
                    'expenseId': expense.id,
                  }),
                  icon: const Icon(Icons.open_in_full_rounded, size: 14),
                  label: const Text('Open'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tealDark,
                    side: BorderSide(
                        color: AppColors.tealDark.withValues(alpha: 0.4)),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
              if (_ownedByMe) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.pushNamed('edit-expense', pathParameters: {
                      'expenseId': expense.id,
                    }),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Edit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.tealDark,
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _paidByRow() {
    final isSelf = _ownedByMe;
    final name = isSelf ? '${expense.paidBy.name} (Me)' : expense.paidBy.name;
    return Row(
      children: [
        AvatarWidget(
          name: expense.paidBy.name,
          imageUrl: expense.paidBy.avatarUrl,
          radius: 14,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$name paid the full amount',
            style: AppTextStyles.body2(isDark).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '+${_money(expense.amount, expense.currency)}',
          style: AppTextStyles.body2(isDark).copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _splitRow(SplitModel s) {
    final isSelf = myId != null && s.userId == myId;
    final name = isSelf ? '${s.userName} (Me)' : s.userName;
    final statusIcon = s.isSettled
        ? Icon(Icons.check_circle_rounded,
            size: 14, color: AppColors.success)
        : Icon(Icons.schedule_rounded,
            size: 14, color: AppColors.textSecondary(isDark));
    return Row(
      children: [
        AvatarWidget(
          name: s.userName,
          imageUrl: s.userAvatarUrl,
          radius: 12,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: AppTextStyles.body2(isDark).copyWith(
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        statusIcon,
        const SizedBox(width: 4),
        Text(
          _money(s.owedShare, expense.currency),
          style: AppTextStyles.body2(isDark).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _miniLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption(isDark).copyWith(
        color: AppColors.textSecondary(isDark),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        fontSize: 10,
      ),
    );
  }

  Widget _receiptThumb(String base64Data) {
    // Off-thread decode via compute() — receipts can be 200KB-1MB and
    // base64Decode at that size measurably blocks the main isolate
    // (drops a frame or two). The small placeholder shows during decode
    // and Image.memory paints once bytes are ready.
    return _AsyncReceiptThumb(base64Data: base64Data, isDark: isDark);
  }

  String _money(double v, String currency) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: currency,
        decimalDigits: 0,
      ).format(v);

  Color? _categoryColor(String hex) {
    var s = hex.replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    final value = int.tryParse(s, radix: 16);
    return value == null ? null : Color(value);
  }
}

// ============================================================================
// Settlement card (collapsed + expanded states)
// ============================================================================

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.settlement,
    required this.isDark,
    required this.myId,
    required this.isExpanded,
    required this.onTap,
  });

  final SettlementModel settlement;
  final bool isDark;
  final String? myId;
  final bool isExpanded;
  final VoidCallback onTap;

  bool get _byMe => myId != null && settlement.fromUser.id == myId;
  bool get _toMe => myId != null && settlement.toUser.id == myId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _collapsedHeader(),
              if (isExpanded) _expandedBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collapsedHeader() {
    final fromLabel = _byMe ? 'You' : settlement.fromUser.name;
    final toLabel = _toMe ? 'you' : settlement.toUser.name;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: fromLabel,
                        style: AppTextStyles.body2(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      TextSpan(
                        text: ' paid ',
                        style: AppTextStyles.body2(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 13.5,
                        ),
                      ),
                      TextSpan(
                        text: toLabel,
                        style: AppTextStyles.body2(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _statusChip(),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat.jm().format(settlement.date),
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _money(settlement.amount, settlement.currency),
                style: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final color = settlement.status == SettlementStatus.completed
        ? AppColors.success
        : settlement.status == SettlementStatus.pending
            ? AppColors.textSecondary(isDark)
            : AppColors.errorText(isDark);
    final label = settlement.status.name.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _expandedBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 18,
            thickness: 1,
            color: AppColors.divider(isDark).withValues(alpha: 0.5),
          ),
          _personRow(
            label: 'FROM',
            user: settlement.fromUser,
            isSelf: _byMe,
          ),
          const SizedBox(height: 8),
          _personRow(
            label: 'TO',
            user: settlement.toUser,
            isSelf: _toMe,
          ),
          if (settlement.note != null &&
              settlement.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Note: ${settlement.note}',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _personRow({
    required String label,
    required user,
    required bool isSelf,
  }) {
    final name = isSelf ? '${user.name} (Me)' : user.name;
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AvatarWidget(name: user.name, imageUrl: user.avatarUrl, radius: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: AppTextStyles.body2(isDark).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _money(double v, String currency) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: currency,
        decimalDigits: 0,
      ).format(v);
}

// ============================================================================
// Empty / loading / error / flat-list helpers
// ============================================================================

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({required this.isDark, required this.showingFilter});
  final bool isDark;
  final bool showingFilter;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tealDark.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 26,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              showingFilter
                  ? 'No activity matches'
                  : 'No activity yet',
              style: AppTextStyles.headline3(isDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              showingFilter
                  ? 'Try a different filter or clear the search.'
                  : 'Expenses and settlements added in this group will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({
    required this.isDark,
    required this.message,
    required this.onRetry,
  });
  final bool isDark;
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: AppColors.warning,
            ),
            const SizedBox(height: 10),
            Text(
              "Couldn't load activity",
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 4,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
        ),
      ),
    );
  }
}

sealed class _FlatEntry {}

class _HeaderEntry extends _FlatEntry {
  _HeaderEntry(this.label);
  final String label;
}

class _ItemEntry extends _FlatEntry {
  _ItemEntry(this.item);
  final GroupFeedItem item;
}

/// Decodes a receipt's base64 payload off the main isolate (`compute`)
/// and renders the image once bytes arrive. While decoding, shows a
/// thin shimmer-like placeholder so the expanded card doesn't jump
/// height when the bytes land. Receipts can be 200KB-1MB; doing this
/// inline blocks the UI for 30-100ms on mid-tier Androids.
class _AsyncReceiptThumb extends StatefulWidget {
  const _AsyncReceiptThumb({
    required this.base64Data,
    required this.isDark,
  });
  final String base64Data;
  final bool isDark;
  @override
  State<_AsyncReceiptThumb> createState() => _AsyncReceiptThumbState();
}

class _AsyncReceiptThumbState extends State<_AsyncReceiptThumb> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_AsyncReceiptThumb old) {
    super.didUpdateWidget(old);
    if (old.base64Data != widget.base64Data) {
      _bytes = null;
      _failed = false;
      _decode();
    }
  }

  Future<void> _decode() async {
    try {
      final bytes = await compute<String, Uint8List>(
        _decodeBase64Receipt,
        widget.base64Data,
      );
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    if (_bytes == null) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.cardBg(widget.isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider(widget.isDark)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        _bytes!,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Top-level so `compute` can spawn the isolate entry point.
Uint8List _decodeBase64Receipt(String raw) {
  final cleaned = raw.contains(',') ? raw.split(',').last : raw;
  return base64Decode(cleaned);
}
