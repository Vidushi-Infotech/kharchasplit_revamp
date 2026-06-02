import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/group_model.dart';
import '../../modules/groups/state/groups_provider.dart';

/// Bottom sheet shown when the user taps the floating Create (+) button.
/// Lets them pick a group to add an expense to. Tapping a group closes
/// the sheet and navigates to `/add-expense/:groupId`. There's also a
/// secondary "Create a new group" action for the empty / new-group case.
class PickGroupForExpenseSheet extends ConsumerStatefulWidget {
  const PickGroupForExpenseSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PickGroupForExpenseSheet(),
    );
  }

  @override
  ConsumerState<PickGroupForExpenseSheet> createState() =>
      _PickGroupForExpenseSheetState();
}

class _PickGroupForExpenseSheetState
    extends ConsumerState<PickGroupForExpenseSheet> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
        _searchFocus.unfocus();
      }
    });
    if (_searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  List<GroupModel> _filter(List<GroupModel> groups) {
    if (_query.isEmpty) return groups;
    final q = _query.toLowerCase();
    return groups.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(groupsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background(isDark),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Add an expense',
                            style: AppTextStyles.body1(isDark).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pick a group to add the expense to',
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CircleIconButton(
                      isDark: isDark,
                      icon: _searching
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      semanticLabel: _searching
                          ? 'Close search'
                          : 'Search groups',
                      onTap: _toggleSearch,
                    ),
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      isDark: isDark,
                      icon: Icons.close_rounded,
                      semanticLabel: 'Close',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: _searching
                    ? TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (q) => setState(() => _query = q),
                        textInputAction: TextInputAction.search,
                        style: AppTextStyles.body2(isDark)
                            .copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.cardBg(isDark),
                          isDense: true,
                          hintText: 'Search groups',
                          hintStyle: AppTextStyles.body2(isDark).copyWith(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppColors.textSecondary(isDark),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: 40, minHeight: 40),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 16),
                                  color: AppColors.textSecondary(isDark),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.divider(isDark)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.divider(isDark)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.tealDark
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      )
                    : _CreateGroupCta(
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/home/create-group');
                        },
                      ),
              ),
              Expanded(
                child: groupsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => _ErrorState(
                    isDark: isDark,
                    message: err.toString(),
                    onRetry: () =>
                        ref.read(groupsProvider.notifier).refresh(),
                  ),
                  data: (groups) {
                    final visible = _filter(groups);
                    if (groups.isEmpty) {
                      return _EmptyState(
                        isDark: isDark,
                        onCreateGroup: () {
                          Navigator.of(context).pop();
                          context.push('/home/create-group');
                        },
                      );
                    }
                    if (visible.isEmpty) {
                      return _NoResults(isDark: isDark, query: _query);
                    }
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      children: [
                        for (int i = 0; i < visible.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GroupRow(
                              group: visible[i],
                              isDark: isDark,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.pushNamed(
                                  'add-expense-to-group',
                                  pathParameters: {
                                    'groupId': visible[i].id,
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.isDark,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
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

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.isDark,
    required this.onTap,
  });

  final GroupModel group;
  final bool isDark;
  final VoidCallback onTap;

  static const String _defaultPeopleEmoji = '👥';

  @override
  Widget build(BuildContext context) {
    final emoji = group.coverEmoji;
    final hasCustomEmoji =
        emoji.isNotEmpty && emoji != _defaultPeopleEmoji;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
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
                    color:
                        AppColors.divider(isDark).withValues(alpha: 0.6),
                  ),
                ),
                child: hasCustomEmoji
                    ? Text(emoji,
                        style: const TextStyle(fontSize: 20))
                    : Icon(
                        Icons.group_rounded,
                        size: 20,
                        color: AppColors.textSecondary(isDark),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.name,
                      style: AppTextStyles.body1(isDark).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupCta extends StatelessWidget {
  const _CreateGroupCta({required this.isDark, required this.onTap});
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create a new group',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.tealDark.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tealDark.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    size: 18,
                    color: AppColors.tealDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create a new group',
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Start splitting with new people',
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.tealDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark, required this.onCreateGroup});
  final bool isDark;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.group_add_rounded,
              size: 26,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No groups yet',
            style: AppTextStyles.headline3(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Create a group first, then you can split expenses with its members.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreateGroup,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create a group'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tealDark,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.isDark, required this.query});
  final bool isDark;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 32,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 10),
            Text(
              query.isEmpty
                  ? 'No groups match'
                  : 'No groups match "$query"',
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
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
              size: 36,
              color: AppColors.warning,
            ),
            const SizedBox(height: 10),
            Text(
              "Couldn't load groups",
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
