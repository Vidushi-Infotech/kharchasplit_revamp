import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/state/sessions_provider.dart';

class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        title: 'Active sessions',
        onBack: () => context.pop(),
        onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 1100 ? 640 : 760,
            ),
            child: sessionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorView(
                isDark: isDark,
                message: err.toString(),
                onRetry: () =>
                    ref.read(sessionsProvider.notifier).refresh(),
              ),
              data: (sessions) => _Body(
                sessions: sessions,
                isDark: isDark,
                onRevoke: (id) =>
                    _confirmRevoke(context, ref, id),
                onSignOutOthers: () =>
                    _confirmRevokeOthers(context, ref, sessions),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: const Text(
          'The session will end immediately. The device will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(sessionsProvider.notifier).revoke(id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session signed out'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not sign out: $e'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmRevokeOthers(
    BuildContext context,
    WidgetRef ref,
    List<SessionModel> sessions,
  ) async {
    final others = sessions.where((s) => !s.isCurrent).length;
    if (others == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other sessions to sign out'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out all other devices?'),
        content: Text(
          'This will end $others other ${others == 1 ? 'session' : 'sessions'}. '
          'Your current device stays signed in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out others'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final revoked = await ref
          .read(sessionsProvider.notifier)
          .revokeAllOthers();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed out $revoked other devices'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not sign out others: $e'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.sessions,
    required this.isDark,
    required this.onRevoke,
    required this.onSignOutOthers,
  });

  final List<SessionModel> sessions;
  final bool isDark;
  final ValueChanged<String> onRevoke;
  final VoidCallback onSignOutOthers;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices_other_rounded,
                size: 48,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(height: 12),
              Text(
                'No active sessions',
                style: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final others = sessions.where((s) => !s.isCurrent).length;
    final current = sessions.where((s) => s.isCurrent).toList();
    final rest = sessions.where((s) => !s.isCurrent).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _Intro(isDark: isDark, count: sessions.length),
        const SizedBox(height: 22),
        if (current.isNotEmpty) ...[
          _SectionLabel(label: 'THIS DEVICE', isDark: isDark),
          const SizedBox(height: 8),
          _SessionsCard(
            sessions: current,
            isDark: isDark,
            onRevoke: onRevoke,
          ),
          const SizedBox(height: 22),
        ],
        if (rest.isNotEmpty) ...[
          _SectionLabel(
            label: 'OTHER DEVICES · ${rest.length}',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _SessionsCard(
            sessions: rest,
            isDark: isDark,
            onRevoke: onRevoke,
          ),
          const SizedBox(height: 16),
          _SignOutOthersButton(
            isDark: isDark,
            count: others,
            onTap: onSignOutOthers,
          ),
        ],
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.isDark, required this.count});
  final bool isDark;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.tealDark.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.devices_rounded,
              size: 18,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count active ${count == 1 ? 'session' : 'sessions'}. '
              "If you don't recognize one, sign it out below.",
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
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

class _SessionsCard extends StatelessWidget {
  const _SessionsCard({
    required this.sessions,
    required this.isDark,
    required this.onRevoke,
  });

  final List<SessionModel> sessions;
  final bool isDark;
  final ValueChanged<String> onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sessions.length; i++) ...[
            _SessionRow(
              session: sessions[i],
              isDark: isDark,
              onRevoke: onRevoke,
            ),
            if (i < sessions.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.isDark,
    required this.onRevoke,
  });

  final SessionModel session;
  final bool isDark;
  final ValueChanged<String> onRevoke;

  @override
  Widget build(BuildContext context) {
    final lastUsed = session.lastUsedAt ?? session.createdAt;
    final lastUsedRelative = _relativeTime(lastUsed);
    final exact = DateFormat('d MMM yyyy · h:mm a').format(lastUsed);
    final platform = session.platform ?? '';
    final title = session.deviceName ??
        (platform.isNotEmpty ? '$platform device' : 'Unknown device');
    final subtitleParts = <String>[
      if (session.osVersion != null && session.osVersion!.isNotEmpty)
        session.osVersion!,
      if (session.appVersion != null && session.appVersion!.isNotEmpty)
        'v${session.appVersion}',
      if (session.ipAddress != null && session.ipAddress!.isNotEmpty)
        session.ipAddress!,
    ];
    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: session.isCurrent
                  ? AppColors.success.withValues(alpha: 0.14)
                  : AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: session.isCurrent
                    ? AppColors.success.withValues(alpha: 0.30)
                    : AppColors.divider(isDark).withValues(alpha: 0.6),
              ),
            ),
            child: Icon(
              _iconForPlatform(session.platform, session.isCurrent),
              size: 18,
              color: session.isCurrent
                  ? AppColors.success
                  : AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.isCurrent) ...[
                      const SizedBox(width: 6),
                      _CurrentBadge(),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  session.isCurrent
                      ? 'Active now · $exact'
                      : 'Last active $lastUsedRelative · $exact',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!session.isCurrent)
            IconButton(
              tooltip: 'Sign out this device',
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              onPressed: () => onRevoke(session.id),
            ),
        ],
      ),
    );
  }

  IconData _iconForPlatform(String? platform, bool isCurrent) {
    switch (platform?.toLowerCase()) {
      case 'android':
      case 'ios':
        return Icons.smartphone_rounded;
      case 'web':
        return Icons.public_rounded;
      case 'macos':
      case 'windows':
      case 'linux':
        return Icons.laptop_mac_rounded;
      default:
        return isCurrent
            ? Icons.smartphone_rounded
            : Icons.devices_other_rounded;
    }
  }

  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _CurrentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'CURRENT',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SignOutOthersButton extends StatelessWidget {
  const _SignOutOthersButton({
    required this.isDark,
    required this.count,
    required this.onTap,
  });

  final bool isDark;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sign out all other devices',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sign out all other devices',
                  style: AppTextStyles.body1(isDark).copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
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
              size: 40,
              color: AppColors.warning,
            ),
            const SizedBox(height: 10),
            Text(
              "Couldn't load sessions",
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
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

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.isDark,
    required this.title,
    required this.onBack,
    required this.onRefresh,
  });

  final bool isDark;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

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
              _CircleIcon(
                icon: Icons.arrow_back_rounded,
                isDark: isDark,
                onTap: onBack,
                label: 'Back',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _CircleIcon(
                icon: Icons.refresh_rounded,
                isDark: isDark,
                onTap: onRefresh,
                label: 'Refresh',
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.textPrimary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
