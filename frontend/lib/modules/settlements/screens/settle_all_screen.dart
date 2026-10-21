import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/settlement_model.dart';
import '../../friends/state/friends_provider.dart';
import '../state/settle_all_controller.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/settle_all_summary_card.dart';
import '../widgets/settle_upi_section.dart';

/// "Settle all balances" with one friend in one currency: every shared
/// group's balance is settled by one payment of the net (Splitwise style).
/// Records exactly the amounts shown; if they changed meanwhile the server
/// answers 409, the new amounts replace the old and the user taps again.
class SettleAllScreen extends ConsumerStatefulWidget {
  const SettleAllScreen({
    super.key,
    required this.friendId,
    required this.currency,
  });

  final String friendId;

  /// ISO code (e.g. `INR`).
  final String currency;

  @override
  ConsumerState<SettleAllScreen> createState() => _SettleAllScreenState();
}

class _SettleAllScreenState extends ConsumerState<SettleAllScreen> {
  final _notesController = TextEditingController();

  /// Feeds [SettleUpiSection], which follows an amount field; here it is
  /// the (read-only) total.
  final _upiAmountController = TextEditingController();

  /// Null until the user picks one — sent as null rather than a guess.
  SettlementMethod? _method;

  SettleAllKey get _key =>
      (friendId: widget.friendId, currency: widget.currency);

  @override
  void dispose() {
    _notesController.dispose();
    _upiAmountController.dispose();
    super.dispose();
  }

  Future<void> _record(List<SettleAllLine> shown, String friendName) async {
    final notes = _notesController.text.trim();
    final ok = await ref
        .read(settleAllControllerProvider(_key).notifier)
        .submit(
          shown: shown,
          method: _method,
          notes: notes.isEmpty ? null : notes,
        );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.settledUpWithName(friendName)),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  /// Called only after the user confirmed the UPI transfer went through.
  Future<void> _recordUpi(
    List<SettleAllLine> shown,
    double paid,
    String friendName,
  ) async {
    final notes = _notesController.text.trim();
    final message = await ref
        .read(settleAllControllerProvider(_key).notifier)
        .submitAfterUpi(
          shown: shown,
          paid: paid,
          friendName: friendName,
          notes: notes.isEmpty ? null : notes,
        );
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    // Compact < 600 / standard 600–1100 / large > 1100.
    final pad = width < 600 ? 16.0 : (width < 1100 ? 24.0 : 32.0);
    final friendAsync = ref.watch(friendByIdProvider(widget.friendId));
    final linesAsync = ref.watch(settleAllLinesProvider(_key));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text(AppStrings.settleAllBalances),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: linesAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.all(pad),
          child: const ShimmerList(type: ShimmerListType.friend, itemCount: 3),
        ),
        error: (err, _) => ErrorStateWidget(
          title: 'Failed to load balances',
          message: err.toString(),
          onRetry: () => ref.invalidate(friendsProvider),
        ),
        data: (lines) {
          final name = friendAsync.value?.user.name ?? 'your friend';
          if (lines == null || lines.isEmpty) {
            return EmptyStateWidget(
              icon: '🎉',
              title: AppStrings.nothingToSettle,
              subtitle: AppStrings.nothingToPayName(name),
              actionLabel: 'Back',
              onActionPressed: () => context.pop(),
            );
          }
          return _buildForm(isDark, pad, lines, name);
        },
      ),
    );
  }

  Widget _buildForm(
    bool isDark,
    double pad,
    List<SettleAllLine> lines,
    String name,
  ) {
    final state = ref.watch(settleAllControllerProvider(_key));
    final total = settleAllTotal(lines);
    final canPay = total > 0.005;
    final upiAmount = total.toStringAsFixed(2);
    if (_upiAmountController.text != upiAmount) {
      // Not during build: the UPI section listens to this controller.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _upiAmountController.text = upiAmount;
      });
    }
    final totalText = CurrencyFormatter.format(
      total,
      currency: widget.currency,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              if (state.balancesChanged) ...[
                const SettleAllChangedBanner(),
                const SizedBox(height: 12),
              ],
              SettleAllSummaryCard(
                lines: lines,
                friendName: name,
                currency: widget.currency,
              ),
              const SizedBox(height: 20),
              if (!canPay)
                Text(
                  AppStrings.nothingToPayName(name),
                  style: AppTextStyles.body2(isDark),
                )
              else ...[
                PaymentMethodSelector(
                  selected: _method,
                  onChanged: (m) => setState(() => _method = m),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: AppStrings.notesOptional,
                  hint: 'e.g. Trip + flat dues',
                  controller: _notesController,
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 20),
                SettleUpiSection(
                  recipientUserId: widget.friendId,
                  recipientName: name,
                  currency: widget.currency,
                  groupName: AppStrings.settleAllBalances,
                  amountController: _upiAmountController,
                  onConfirmedPaid: () => _recordUpi(lines, total, name),
                ),
                if (state.error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.error!,
                      style: AppTextStyles.error(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Semantics(
                  button: true,
                  label: AppStrings.recordAmountPayment(totalText),
                  child: PrimaryButton(
                    label: AppStrings.recordAmountPayment(totalText),
                    isLoading: state.submitting,
                    onPressed: state.submitting
                        ? null
                        : () => _record(lines, name),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
