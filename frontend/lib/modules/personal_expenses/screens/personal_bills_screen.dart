import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/personal_bill_model.dart';
import '../state/personal_bills_provider.dart';
import '../widgets/bills/bill_editor_sheet.dart';
import '../widgets/bills/bill_row.dart';
import '../widgets/bills/pay_bill_sheet.dart';
import '../widgets/insights/insights_card.dart';

/// All bills, in three groups: overdue, due soon (inside their reminder
/// window) and later. Opened from the home's Upcoming bills and from a
/// "bill due" notification.
class PersonalBillsScreen extends ConsumerWidget {
  const PersonalBillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < Breakpoints.shellTablet ? 20.0 : 32.0;
    final async = ref.watch(personalBillsProvider);

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
          title: AppStrings.billLoadError,
          message: e.toString(),
          onRetry: () => ref.read(personalBillsProvider.notifier).refresh(),
        ),
      ],
      data: (bills) => bills.isEmpty
          ? [
              const SizedBox(height: 24),
              EmptyStateWidget(
                icon: '🧾',
                iconSize: 52,
                title: AppStrings.billsEmptyTitle,
                subtitle: AppStrings.billsEmptyBody,
                actionLabel: AppStrings.billAdd,
                onActionPressed: () => BillEditorSheet.show(context),
              ),
            ]
          : [
              for (final (status, title) in [
                (BillStatus.overdue, AppStrings.billsOverdue),
                (BillStatus.due, AppStrings.billsDueSoon),
                (BillStatus.upcoming, AppStrings.billsLater),
              ])
                if (bills.any((b) => b.status == status)) ...[
                  InsightsCard(
                    title: title,
                    child: Column(
                      children: [
                        for (final b in bills.where((b) => b.status == status))
                          BillRow(
                            bill: b,
                            onTap: () => BillEditorSheet.show(context, bill: b),
                            onPay: () => PayBillSheet.show(context, b),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
            ],
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.background(isDark),
        surfaceTintColor: Colors.transparent,
        title: const Text(AppStrings.bills),
        leading: GlassBackButton.appBarLeading(context),
        actions: [
          GlassIconButton(
            icon: Icons.add_rounded,
            sfSymbol: 'plus',
            tooltip: AppStrings.billAdd,
            onPressed: () => BillEditorSheet.show(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(personalBillsProvider.notifier).refresh(),
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
              children: body,
            ),
          ),
        ),
      ),
    );
  }
}
