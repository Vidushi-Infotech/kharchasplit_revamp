import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/personal_transfer_model.dart';
import '../../../models/wallet_source_model.dart';
import '../state/personal_expenses_provider.dart';
import '../state/wallet_provider.dart';
import '../widgets/account_style.dart';
import '../widgets/accounts/transfer_sheet.dart';
import '../widgets/insights/insights_card.dart';
import '../widgets/personal_expense_tile.dart';
import '../widgets/wallet_setup_sheet.dart';

/// One account: its balance, the money moved in and out of it, and the
/// latest entries paid from / received into it.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < Breakpoints.shellTablet ? 20.0 : 32.0;
    final wallet = ref.watch(walletProvider).value;
    final source = wallet?.sources.where((s) => s.id == accountId).firstOrNull;
    final entries = (ref.watch(personalExpensesProvider).value ?? const [])
        .where((e) => e.accountId == accountId)
        .take(20)
        .toList();
    final transfers = ref.watch(accountTransfersProvider(accountId));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.background(isDark),
        surfaceTintColor: Colors.transparent,
        title: Text(source?.name ?? AppStrings.accounts),
        actions: [
          IconButton(
            tooltip: AppStrings.accountManage,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => WalletSetupSheet.show(context),
          ),
        ],
      ),
      body: source == null
          ? (wallet == null
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: ShimmerList(
                      type: ShimmerListType.expense,
                      itemCount: 3,
                    ),
                  )
                // Archived from the manage sheet: nothing to show here.
                : EmptyStateWidget(
                    icon: '🏦',
                    title: AppStrings.accountsEmptyTitle,
                    subtitle: '',
                    actionLabel: AppStrings.accounts,
                    onActionPressed: () => context.pop(),
                  ))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(walletProvider);
                ref.invalidate(accountTransfersProvider(accountId));
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      8,
                      gutter,
                      bottomNavReserve(context.widthTier, compact: 120),
                    ),
                    children: [
                      _BalanceCard(
                        source: source,
                        canTransfer: (wallet?.sources.length ?? 0) >= 2,
                      ),
                      ..._transfers(context, ref, transfers, wallet!),
                      const SizedBox(height: 14),
                      InsightsCard(
                        title: AppStrings.accountEntries,
                        child: entries.isEmpty
                            ? Text(
                                AppStrings.accountNoActivity,
                                style: AppTextStyles.caption(isDark).copyWith(
                                  color: AppColors.textSecondary(isDark),
                                ),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < entries.length; i++)
                                    PersonalExpenseTile(
                                      expense: entries[i],
                                      showDivider: i < entries.length - 1,
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _transfers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<PersonalTransfer>> async,
    WalletState wallet,
  ) {
    final list = async.value ?? const <PersonalTransfer>[];
    if (list.isEmpty) return const [];
    String nameOf(String id) =>
        wallet.sources.where((s) => s.id == id).firstOrNull?.name ?? '—';
    return [
      const SizedBox(height: 14),
      InsightsCard(
        title: AppStrings.accountTransfers,
        child: Column(
          children: [
            for (final t in list)
              _TransferRow(
                transfer: t,
                incoming: t.toAccountId == accountId,
                otherName: nameOf(
                  t.toAccountId == accountId ? t.fromAccountId : t.toAccountId,
                ),
                onDelete: () => _confirmDelete(context, ref, t),
              ),
          ],
        ),
      ),
    ];
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PersonalTransfer t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.accountDeleteTransfer),
        content: Text(CurrencyFormatter.format(t.amount, currency: '₹')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(walletProvider.notifier).deleteTransfer(t.id);
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.source, required this.canTransfer});

  final WalletSource source;
  final bool canTransfer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealLight, AppColors.tealDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(source.type.icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                source.type.label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            accountBalanceText(source),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: canTransfer
                ? () => TransferSheet.show(context, fromId: source.id)
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.accountTransferNeedTwo),
                    ),
                  ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text(AppStrings.accountTransfer),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.transfer,
    required this.incoming,
    required this.otherName,
    required this.onDelete,
  });

  final PersonalTransfer transfer;
  final bool incoming;
  final String otherName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = incoming ? AppColors.success : AppColors.warning;
    final note = transfer.note;
    return InkWell(
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(
              incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${incoming ? AppStrings.accountTransferFrom : AppStrings.accountTransferTo} $otherName',
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    [
                      DateFormat('d MMM').format(transfer.date),
                      if (note != null && note.isNotEmpty) note,
                    ].join(' · '),
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${incoming ? '+' : '-'}'
              '${CurrencyFormatter.format(transfer.amount, currency: '₹')}',
              style: AppTextStyles.body1(isDark).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            IconButton(
              tooltip: AppStrings.accountDeleteTransfer,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
