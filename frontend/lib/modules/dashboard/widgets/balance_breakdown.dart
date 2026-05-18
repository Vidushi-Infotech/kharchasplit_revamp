import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../groups/widgets/group_cover_thumb.dart';

/// Shared scaffold for the "You're owed" and "You owe" screens.
///
/// Both screens share the same shape: a back button, an overline + big total
/// + subtitle, then a grouped list of contributing groups (with an empty
/// state when there's nothing to show).
class BalanceBreakdownView extends StatelessWidget {
  const BalanceBreakdownView({
    super.key,
    required this.overline,
    required this.total,
    required this.subtitle,
    required this.accent,
    required this.amountSign,
    required this.groups,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String overline;
  final double total;
  final String subtitle;
  final Color accent;
  final String amountSign; // '+' or '-'
  final List<dynamic> groups;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptyMessage;

  static const String _defaultPeopleEmoji = '👥';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final formattedTotal = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(total.abs());

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(isDark: isDark, onBack: () => context.pop()),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 1100 ? 720 : 900,
            ),
            child: groups.isEmpty
                ? _Empty(
                    emoji: emptyEmoji,
                    title: emptyTitle,
                    message: emptyMessage,
                    isDark: isDark,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _Header(
                        overline: overline,
                        total: '$amountSign$formattedTotal',
                        subtitle: subtitle,
                        accent: accent,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),
                      _GroupsCard(
                        groups: groups,
                        accent: accent,
                        amountSign: amountSign,
                        isDark: isDark,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.isDark, required this.onBack});

  final bool isDark;
  final VoidCallback onBack;

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
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.overline,
    required this.total,
    required this.subtitle,
    required this.accent,
    required this.isDark,
  });

  final String overline;
  final String total;
  final String subtitle;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline,
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total,
            style: AppTextStyles.headline1(isDark).copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.1,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupsCard extends StatelessWidget {
  const _GroupsCard({
    required this.groups,
    required this.accent,
    required this.amountSign,
    required this.isDark,
  });

  final List<dynamic> groups;
  final Color accent;
  final String amountSign;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < groups.length; i++) ...[
            _GroupRow(
              group: groups[i],
              accent: accent,
              amountSign: amountSign,
              isDark: isDark,
              onTap: () => context.pushNamed(
                'group-detail',
                pathParameters: {'groupId': groups[i].id as String},
              ),
            ),
            if (i < groups.length - 1)
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

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.accent,
    required this.amountSign,
    required this.isDark,
    required this.onTap,
  });

  final dynamic group;
  final Color accent;
  final String amountSign;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverEmoji = (group.coverEmoji as String?) ?? '';
    final coverImageBase64 = group.coverImageBase64 as String?;
    final amount = (group.myBalance as num).toDouble().abs();
    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.divider(isDark).withValues(alpha: 0.6),
                  ),
                ),
                child: GroupCoverThumb(
                  coverImageBase64: coverImageBase64,
                  coverEmoji: coverEmoji,
                  size: 40,
                  borderRadius: 11,
                  emojiFontSize: 20,
                  fallbackIconColor: AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.name as String,
                      style: AppTextStyles.body1(isDark).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.memberCount} members',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$amountSign$formatted',
                style: AppTextStyles.body1(isDark).copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.emoji,
    required this.title,
    required this.message,
    required this.isDark,
  });

  final String emoji;
  final String title;
  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTextStyles.headline3(isDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
