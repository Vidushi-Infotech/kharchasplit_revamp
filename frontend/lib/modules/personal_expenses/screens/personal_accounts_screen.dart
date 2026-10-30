import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/wallet_source_model.dart';
import '../state/wallet_provider.dart';
import '../widgets/account_style.dart';
import '../widgets/accounts/transfer_sheet.dart';
import '../widgets/insights/insights_card.dart';
import '../widgets/wallet_setup_sheet.dart';

/// Personal mode's Accounts tab: what's in each account (cash, bank, cards,
/// e-wallets), the total, and moving money between them. An account opens
/// its own page with its entries and transfers.
class PersonalAccountsScreen extends ConsumerWidget {
  const PersonalAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < Breakpoints.shellTablet ? 20.0 : 32.0;
    final async = ref.watch(walletProvider);

    final List<Widget> body = async.when(
      skipLoadingOnReload: true,
      // ShimmerList scrolls itself, so it needs a height inside this list.
      loading: () => const [
        SizedBox(
          height: 360,
          child: ShimmerList(type: ShimmerListType.expense, itemCount: 4),
        ),
      ],
      error: (e, _) => [
        ErrorStateWidget(
          title: AppStrings.accountLoadError,
          message: e.toString(),
          onRetry: () => ref.invalidate(walletProvider),
        ),
      ],
      data: (w) => _sections(context, w),
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(walletProvider),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width < 1100 ? 720 : 900),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  18,
                  gutter,
                  bottomNavReserve(context.widthTier, compact: 120),
                ),
                children: [
                  _Header(
                    isDark: isDark,
                    onManage: () => WalletSetupSheet.show(context),
                  ),
                  const SizedBox(height: 16),
                  ...body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, WalletState w) {
    if (w.sources.isEmpty) {
      return [
        const SizedBox(height: 24),
        EmptyStateWidget(
          icon: '🏦',
          iconSize: 52,
          title: AppStrings.accountsEmptyTitle,
          subtitle: AppStrings.accountsEmptyBody,
          actionLabel: AppStrings.accountAdd,
          onActionPressed: () => WalletSetupSheet.show(context),
        ),
      ];
    }
    return [
      _TotalCard(wallet: w),
      for (final type in WalletSourceType.values)
        if (w.sources.any((s) => s.type == type)) ...[
          const SizedBox(height: 14),
          InsightsCard(
            title: type.label,
            child: Column(
              children: [
                for (final s in w.sources.where((s) => s.type == type))
                  _AccountRow(
                    source: s,
                    entries:
                        s.entryCount ??
                        w.expenseSourceMap.values
                            .where((id) => id == s.id)
                            .length,
                    onTap: () => context.push('/personal/accounts/${s.id}'),
                  ),
              ],
            ),
          ),
        ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onManage});

  final bool isDark;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.personal.toUpperCase(),
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                child: Text(
                  AppStrings.accounts,
                  style: AppTextStyles.headline1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        // iOS 26 headers use Liquid Glass buttons, like Home's.
        if (GlassIconButton.isGlass)
          GlassIconButton(
            icon: Icons.add_rounded,
            sfSymbol: 'plus',
            tooltip: AppStrings.accountManage,
            onPressed: onManage,
          )
        else
          IconButton(
            tooltip: AppStrings.accountManage,
            onPressed: onManage,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.cardBg(isDark),
              side: BorderSide(color: AppColors.divider(isDark)),
            ),
            icon: Icon(Icons.add_rounded, color: AppColors.textPrimary(isDark)),
          ),
      ],
    );
  }
}

/// Everything added up (cards owed count against it), and Transfer.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.wallet});

  final WalletState wallet;

  @override
  Widget build(BuildContext context) {
    final total = wallet.totalAvailable;
    final canTransfer = wallet.onServer && wallet.sources.length >= 2;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: total < 0
              ? const [Color(0xFFE57373), Color(0xFFC62828)]
              : const [AppColors.tealLight, AppColors.tealDark],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.accountsNetWorth.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(total, currency: '₹'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (wallet.onServer)
            FilledButton.icon(
              onPressed: canTransfer
                  ? () => TransferSheet.show(context)
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

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.source,
    required this.entries,
    required this.onTap,
  });

  final WalletSource source;
  final int entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final owed = source.balance < 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(source.type.icon, size: 19, color: AppColors.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.accountEntryCount(entries),
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              accountBalanceText(source),
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: owed ? AppColors.errorText(isDark) : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
