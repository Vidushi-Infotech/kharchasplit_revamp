import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/search/search_repository.dart';
import '../../../models/category_model.dart';
import '../state/search_provider.dart';

String searchSectionTitle(SearchSection s) => switch (s) {
  SearchSection.groups => AppStrings.groups,
  SearchSection.friends => AppStrings.friends,
  SearchSection.expenses => AppStrings.expenses,
};

class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader({
    super.key,
    required this.row,
    required this.isDark,
  });

  final SearchHeaderRow row;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          '${searchSectionTitle(row.section).toUpperCase()} · ${row.count}',
          style: AppTextStyles.caption(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Shared row chrome: leading, title, subtitle, optional trailing.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    required this.semanticLabel,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool isDark;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AppColors.cardBg(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.divider(isDark)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.body1(
                            isDark,
                          ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppTextStyles.caption(
                              isDark,
                            ).copyWith(color: AppColors.textSecondary(isDark)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _iconBox(IconData icon, Color color, bool isDark) => Container(
  width: 40,
  height: 40,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.14),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Icon(icon, size: 20, color: color),
);

class SearchGroupTile extends StatelessWidget {
  const SearchGroupTile({
    super.key,
    required this.hit,
    required this.isDark,
    required this.onTap,
  });

  final SearchGroupHit hit;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ResultTile(
      leading: _iconBox(Icons.groups_rounded, AppColors.brand, isDark),
      title: hit.name,
      subtitle: hit.isArchived ? AppStrings.archived : null,
      isDark: isDark,
      onTap: onTap,
      semanticLabel:
          '${AppStrings.groups}: ${hit.name}'
          '${hit.isArchived ? ', ${AppStrings.archived}' : ''}',
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary(isDark),
      ),
    );
  }
}

class SearchFriendTile extends StatelessWidget {
  const SearchFriendTile({
    super.key,
    required this.hit,
    required this.isDark,
    required this.onTap,
  });

  final SearchFriendHit hit;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ResultTile(
      leading: AvatarWidget(
        imageUrl: hit.avatarBase64,
        name: hit.name,
        radius: 20,
      ),
      title: hit.name,
      subtitle: null,
      isDark: isDark,
      onTap: onTap,
      semanticLabel: '${AppStrings.friends}: ${hit.name}',
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary(isDark),
      ),
    );
  }
}

class SearchExpenseTile extends StatelessWidget {
  const SearchExpenseTile({
    super.key,
    required this.hit,
    required this.isDark,
    required this.onTap,
  });

  final SearchExpenseHit hit;
  final bool isDark;
  final VoidCallback onTap;

  static final _date = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final category =
        CategoryModel.fromId(hit.category ?? 'other') ?? CategoryModel.other;
    final color = Color(
      0xFF000000 |
          (int.tryParse(category.colorHex.replaceFirst('#', ''), radix: 16) ??
              0x95A5A6),
    );
    final where = hit.isDirect || hit.groupName == null
        ? AppStrings.nonGroup
        : hit.groupName!;
    final subtitle = hit.date == null
        ? where
        : '$where · ${_date.format(hit.date!)}';
    final amount = CurrencyFormatter.format(hit.amount, currency: hit.currency);
    return _ResultTile(
      leading: _iconBox(category.icon, color, isDark),
      title: hit.description,
      subtitle: subtitle,
      isDark: isDark,
      onTap: onTap,
      semanticLabel: '${hit.description}, $amount, $subtitle',
      trailing: Text(
        amount,
        style: AppTextStyles.body2(
          isDark,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
