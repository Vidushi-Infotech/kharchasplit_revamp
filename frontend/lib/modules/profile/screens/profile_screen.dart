import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/buttons/glass_icon_button.dart';
import '../../../components/dialogs/donate_sheet.dart';
import '../../../components/headers/glass_large_title.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/state/auth_provider.dart';
import '../../outbox/state/outbox_provider.dart';
import '../widgets/account_header.dart';
import '../widgets/account_rows.dart';
import '../widgets/default_currency_picker.dart';
import '../widgets/email_verify_sheet.dart';
import '../widgets/export_my_expenses_action.dart';
import '../widgets/help_support_sheet.dart';
import '../widgets/logout_sheet.dart';
import '../widgets/upi_id_row.dart';

/// Default-currency preference row on the profile screen. Hidden until the
/// preference is actually honoured by the create-group / add-expense flows;
/// today it saves to the backend but nothing reads it, so showing it would
/// mislead. Flip the flag to bring the row back — the picker and update
/// path still work.
const bool _kShowDefaultCurrency = false;

/// Account tab, Splitwise-style: a flat header (avatar, name, email,
/// phone), then flat sections — Preferences, Tools, Feedback — and Log out
/// at the bottom. Compact is full width; standard (600–1100) and large
/// (> 1100) center the same list at 640 / 820.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < 600
        ? double.infinity
        : (width < 1100 ? 640.0 : 820.0);

    // iOS 26: large title that collapses into the button row on scroll.
    final glass = GlassIconButton.isGlass;
    final top = glass ? GlassLargeTitleFrame.topInset(context) : 0.0;
    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _AccountList(top: top),
      ),
    );

    if (glass) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        body: GlassLargeTitleFrame(
          title: AppStrings.account,
          leading: GlassBackButton.appBarLeading(
            context,
            implyLeading: context.canPop(),
          ),
          actions: const [DonateHeartButton(size: 38, iconSize: 18)],
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text(AppStrings.account),
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.background(isDark),
        automaticallyImplyLeading: context.canPop(),
        leading: GlassBackButton.appBarLeading(
          context,
          implyLeading: context.canPop(),
        ),
        actions: const [
          DonateHeartButton(size: 38, iconSize: 18),
          SizedBox(width: 12),
        ],
      ),
      body: body,
    );
  }
}

class _AccountList extends ConsumerWidget {
  const _AccountList({required this.top});

  /// Space under the iOS 26 large-title header; 0 elsewhere.
  final double top;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final unsynced = ref.watch(unsyncedCountProvider);
    final verifyEmail = user?.email.trim() ?? '';

    return RefreshIndicator(
      color: AppColors.brand,
      edgeOffset: top,
      onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: top,
          bottom: shellBottomReserve(context, context.widthTier, compact: 32),
        ),
        children: [
          AccountHeader(
            user: user,
            onVerifyEmail: verifyEmail.isEmpty
                ? null
                : () => EmailVerifySheet.confirmAndShow(
                    context,
                    email: verifyEmail,
                  ),
          ),
          const MonthSectionHeader(AppStrings.preferences),
          // Changes made offline that aren't on the server yet.
          if (unsynced > 0)
            AccountRow(
              icon: Icons.cloud_upload_outlined,
              label: AppStrings.unsyncedChangesCount(unsynced),
              onTap: () => context.push('/home/profile/unsynced'),
            ),
          AccountRow(
            icon: Icons.notifications_none_rounded,
            label: AppStrings.notifications,
            onTap: () => context.pushNamed('notification-settings'),
          ),
          AccountRow(
            icon: Icons.lock_outline_rounded,
            label: AppStrings.security,
            onTap: () => context.pushNamed('security'),
          ),
          UpiIdRow(upiId: user?.upiId),
          if (_kShowDefaultCurrency)
            _DefaultCurrencyRow(current: user?.preferredCurrency),
          const AccountThemeRow(showDivider: false),
          const MonthSectionHeader(AppStrings.tools),
          AccountRow(
            icon: Icons.bar_chart_rounded,
            label: AppStrings.reports,
            onTap: () => context.push('/reports'),
          ),
          AccountRow(
            icon: Icons.file_download_outlined,
            label: AppStrings.exportMyExpensesCsv,
            showDivider: false,
            onTap: () => exportMyExpensesCsv(context, ref),
          ),
          const MonthSectionHeader(AppStrings.feedback),
          AccountRow(
            icon: Icons.favorite_border_rounded,
            label: AppStrings.supportUsDonate,
            onTap: () => showDonateSheet(context),
          ),
          AccountRow(
            icon: Icons.mail_outline_rounded,
            label: AppStrings.contactUs,
            onTap: () => HelpSupportSheet.show(context),
          ),
          AccountRow(
            icon: Icons.privacy_tip_outlined,
            label: AppStrings.privacyPolicy,
            onTap: () => context.pushNamed('privacy-policy'),
          ),
          AccountRow(
            icon: Icons.description_outlined,
            label: AppStrings.termsOfService,
            onTap: () => context.pushNamed('terms'),
          ),
          const SizedBox(height: 16),
          AccountRow(
            icon: Icons.logout_rounded,
            label: AppStrings.logOut,
            color: AppColors.warning,
            showChevron: false,
            onTap: () => confirmLogout(context, ref),
          ),
          const SizedBox(height: 20),
          const Center(child: AccountVersionFooter()),
        ],
      ),
    );
  }
}

/// Hidden behind [_kShowDefaultCurrency].
class _DefaultCurrencyRow extends ConsumerWidget {
  const _DefaultCurrencyRow({required this.current});

  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = current ?? 'INR';
    return AccountRow(
      icon: Icons.currency_exchange_rounded,
      label: 'Default currency',
      value: DefaultCurrencyPicker.labelFor(code),
      onTap: () => DefaultCurrencyPicker.show(
        context,
        current: code,
        onSelected: (picked) async {
          final messenger = ScaffoldMessenger.of(context);
          final ok = await ref
              .read(authProvider.notifier)
              .updateProfile(preferredCurrency: picked);
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? 'Default currency updated to ${DefaultCurrencyPicker.labelFor(picked)}'
                    : 'Could not update currency',
              ),
              backgroundColor: ok ? null : AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}
