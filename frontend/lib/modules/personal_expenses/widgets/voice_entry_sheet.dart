import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/wallet_source_model.dart';
import '../state/voice_entry_controller.dart';
import '../state/voice_entry_parser.dart';

/// "Say it": listens, shows what was heard and what it understood
/// (amount, expense or income, category, day, account), and hands that to
/// the add form to check and save. Resolves to null when closed.
class VoiceEntrySheet extends ConsumerStatefulWidget {
  const VoiceEntrySheet({super.key, required this.accounts});

  /// For "from cash" / "on card" in what's said.
  final List<WalletSource> accounts;

  static Future<VoiceDraft?> show(
    BuildContext context, {
    List<WalletSource> accounts = const [],
  }) {
    return showModalBottomSheet<VoiceDraft>(
      context: context,
      // Above the floating tab bar.
      useRootNavigator: true,
      // Grows with what was understood, up to the screen.
      isScrollControlled: true,
      // Tall ones stop below the status bar.
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: AppColors.surface(
        Theme.of(context).brightness == Brightness.dark,
      ),
      builder: (_) => VoiceEntrySheet(accounts: accounts),
    );
  }

  @override
  ConsumerState<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends ConsumerState<VoiceEntrySheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    HapticService.instance.tap();
    ref.read(voiceEntryProvider.notifier).start();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final voice = ref.watch(voiceEntryProvider);
    final draft = voice.phase == VoicePhase.done
        ? VoiceEntryParser.parse(voice.transcript, accounts: widget.accounts)
        : null;
    final caption = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark));

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.voiceTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline2(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Center(
              child: _MicButton(
                listening: voice.phase == VoicePhase.listening,
                level: voice.level,
                onTap: voice.phase == VoicePhase.listening
                    ? () => ref.read(voiceEntryProvider.notifier).stop()
                    : _listen,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                switch (voice.phase) {
                  VoicePhase.starting => AppStrings.voiceStarting,
                  VoicePhase.listening when voice.transcript.isEmpty =>
                    AppStrings.voiceListening,
                  VoicePhase.unavailable => AppStrings.voiceUnavailable,
                  VoicePhase.nothingHeard => AppStrings.voiceNothingHeard,
                  _ => '"${voice.transcript}"',
                },
                textAlign: TextAlign.center,
                style: AppTextStyles.body1(isDark).copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontStyle: voice.transcript.isEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (voice.phase == VoicePhase.starting ||
                voice.phase == VoicePhase.listening && voice.transcript.isEmpty)
              Text(
                AppStrings.voiceExamples,
                textAlign: TextAlign.center,
                style: caption,
              ),
            if (draft != null) ...[
              const SizedBox(height: 10),
              _Understood(draft: draft, accounts: widget.accounts),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _listen,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text(AppStrings.voiceAgain),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: draft.amount == null
                          ? null
                          : () => Navigator.of(context).pop(draft),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text(AppStrings.voiceUse),
                    ),
                  ),
                ],
              ),
              if (draft.amount == null) ...[
                const SizedBox(height: 8),
                Text(
                  AppStrings.voiceNoAmount,
                  textAlign: TextAlign.center,
                  style: caption.copyWith(color: AppColors.warning),
                ),
              ],
            ],
            if (voice.phase == VoicePhase.nothingHeard) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _listen,
                child: const Text(AppStrings.voiceAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The round mic: pulses with the voice while listening; tap to stop, or
/// to listen again.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.level,
    required this.onTap,
  });

  final bool listening;
  final double level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? AppStrings.voiceStop : AppStrings.voiceStart,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: listening ? 84 + 36 * level : 84,
                height: listening ? 84 + 36 * level : 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brand.withValues(
                    alpha: listening ? 0.22 : 0.0,
                  ),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening ? AppColors.brand : AppColors.tealDark,
                ),
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the words became, as chips: ₹200 · Expense · Fuel · Yesterday ·
/// Cash.
class _Understood extends StatelessWidget {
  const _Understood({required this.draft, required this.accounts});

  final VoiceDraft draft;
  final List<WalletSource> accounts;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = accounts.where((a) => a.id == draft.accountId).firstOrNull;
    final items = <(IconData, String)>[
      if (draft.amount != null)
        (
          Icons.currency_rupee_rounded,
          CurrencyFormatter.format(draft.amount!, currency: '₹'),
        ),
      (
        draft.isIncome
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded,
        draft.isIncome ? AppStrings.personalIncome : AppStrings.personalExpense,
      ),
      if (draft.category != null) (draft.category!.icon, draft.category!.name),
      if (draft.description.isNotEmpty &&
          draft.description != draft.category?.name)
        (Icons.edit_note_rounded, draft.description),
      if (draft.daysAgo > 0)
        (
          Icons.event_rounded,
          draft.daysAgo == 1
              ? AppStrings.voiceYesterday
              : AppStrings.voiceDaysAgo(draft.daysAgo),
        ),
      if (account != null) (Icons.account_balance_wallet_rounded, account.name),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, text) in items)
          Chip(
            avatar: Icon(icon, size: 16, color: AppColors.brand),
            label: Text(text),
            backgroundColor: AppColors.cardBg(isDark),
            side: BorderSide(color: AppColors.divider(isDark)),
          ),
      ],
    );
  }
}
