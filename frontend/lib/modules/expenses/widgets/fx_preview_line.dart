import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/add_expense_fx.dart';
import '../state/add_expense_provider.dart';
import '../state/fx_rate_provider.dart';
import '../state/fx_rate_text.dart';
import 'fx_rate_sheet.dart';

/// Under the amount of an expense entered in another currency:
/// "≈ ₹8,312.35 at 1 USD = ₹83.12 (16 Oct)", from the live rate for the
/// expense date. When no rate is available: "Exchange rate unavailable ·
/// Enter rate" (the typed rate is then sent as `fxRate`). Editing keeps
/// the rate the expense was saved with while currency and date are
/// unchanged.
class FxPreviewLine extends ConsumerWidget {
  const FxPreviewLine({
    super.key,
    required this.isDark,
    required this.state,
    required this.groupCurrency,
  });

  final bool isDark;
  final AddExpenseState state;

  /// The group's currency as stored on the group (symbol or code).
  final String groupCurrency;

  Future<void> _enterRate(BuildContext context, WidgetRef ref) async {
    final from = state.entryCurrency!;
    final rate = await showFxRateSheet(
      context,
      isDark: isDark,
      from: from,
      to: groupCurrencyCode(groupCurrency),
      initial: state.manualFxRate,
    );
    if (rate == null) return;
    final notifier = ref.read(addExpenseProvider.notifier);
    // Still the same currency (the sheet was open a while).
    if (notifier.state.entryCurrency != from) return;
    notifier.state = notifier.state.copyWith(manualFxRate: rate);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = state.entryCurrency;
    if (from == null) return const SizedBox.shrink();
    final to = groupCurrencyCode(groupCurrency);

    final override = addExpenseFxRateOverride(state);
    if (override != null) {
      final manual = state.manualFxRate != null;
      return _line(
        context,
        _approx(
          override,
          manual ? AppStrings.fxYourRate : fxShortDate(state.savedFx!.date),
        ),
        action: manual ? AppStrings.fxChangeRate : null,
        onAction: manual ? () => _enterRate(context, ref) : null,
      );
    }

    final rate = ref.watch(
      fxRateProvider(fxRateQueryFor(from, to, state.date)),
    );
    return rate.when(
      skipLoadingOnReload: true,
      loading: () => _line(context, AppStrings.fxLoading, muted: true),
      error: (_, _) => _line(
        context,
        AppStrings.fxUnavailable,
        warn: true,
        action: AppStrings.fxEnterRate,
        onAction: () => _enterRate(context, ref),
      ),
      data: (r) =>
          _line(context, _approx(r.rate, fxShortDate(DateTime.parse(r.date)))),
    );
  }

  /// "≈ ₹8,312.35 at 1 USD = ₹83.12 ([note])".
  String _approx(double rate, String note) {
    final converted = CurrencyFormatter.format(
      addExpenseConvertedPaise(state.amount, rate) / 100,
      currency: CurrencyFormatter.symbolFor(groupCurrency),
    );
    final line = fxRateLine(state.entryCurrency!, rate, groupCurrency);
    return AppStrings.fxApprox(converted, line, note);
  }

  Widget _line(
    BuildContext context,
    String text, {
    bool muted = false,
    bool warn = false,
    String? action,
    VoidCallback? onAction,
  }) {
    final color = warn ? AppColors.warning : AppColors.textSecondary(isDark);
    return Semantics(
      liveRegion: true,
      child: Padding(
        // Left-aligned under the amount field (Splitwise-style form).
        padding: EdgeInsets.zero,
        child: Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              text,
              style: AppTextStyles.caption(isDark).copyWith(
                color: color,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.tealDark,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(action),
              ),
          ],
        ),
      ),
    );
  }
}
