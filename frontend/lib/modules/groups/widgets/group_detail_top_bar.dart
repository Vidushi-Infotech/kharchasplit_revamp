import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/buttons/donate_heart_button.dart';
import 'export_group_menu.dart';

class GroupDetailTopBar extends StatelessWidget implements PreferredSizeWidget {
  const GroupDetailTopBar({
    super.key,
    required this.isDark,
    required this.onClose,
    required this.onAddMember,
    required this.onEditGroup,
    required this.onLeaveGroup,
    required this.onDeleteGroup,
    required this.onExportGroup,
    required this.isAdmin,
    required this.canManage,
    this.isDirect = false,
    this.lifecycleItems = const [],
    this.onLifecycleAction,
    this.onDefaultSplit,
    this.onRecurring,
  });

  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onAddMember;

  /// Set when the admin can edit the group. Null disables the option
  /// (e.g. while the detail is still loading).
  final VoidCallback? onEditGroup;
  final VoidCallback onLeaveGroup;
  final VoidCallback onDeleteGroup;

  /// Set when the group is loaded so the user can request a .xlsx ledger.
  /// Null hides the option while still loading.
  final VoidCallback? onExportGroup;

  /// True when the signed-in user is the group's admin/creator.
  final bool isAdmin;

  /// False while the group detail is still loading — hides Leave/Delete to
  /// avoid acting on stale state.
  final bool canManage;

  /// Non-group expenses with one friend: no members, leaving or admin
  /// actions — only Export remains.
  final bool isDirect;

  /// Admin-only archive / complete entries (see group_lifecycle_actions.dart),
  /// shown after "Edit group". Values not handled below go to
  /// [onLifecycleAction].
  final List<PopupMenuEntry<String>> lifecycleItems;
  final ValueChanged<String>? onLifecycleAction;

  /// Opens the admin-only "Default split" editor. Null hides the entry
  /// (still loading, or a direct group).
  final VoidCallback? onDefaultSplit;

  /// Opens the group's "Recurring expenses" list (every member). Null hides
  /// the entry (still loading, or the `recurring` flag is off).
  final VoidCallback? onRecurring;

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
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                isDark: isDark,
                onTap: onClose,
                label: 'Back',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isDirect ? AppStrings.nonGroupExpenses : 'Group',
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const DonateHeartButton(),
              const SizedBox(width: 8),
              // Direct group still loading → nothing to offer yet.
              if (!isDirect || onExportGroup != null)
                Semantics(
                  button: true,
                  label: 'More options',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: PopupMenuButton<String>(
                      color: AppColors.cardBg(isDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.divider(isDark)),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit_group':
                            onEditGroup?.call();
                            break;
                          case 'add_member':
                            onAddMember();
                            break;
                          case 'default_split':
                            onDefaultSplit?.call();
                            break;
                          case 'recurring':
                            onRecurring?.call();
                            break;
                          case 'export':
                            onExportGroup?.call();
                            break;
                          case 'leave':
                            onLeaveGroup();
                            break;
                          case 'delete':
                            onDeleteGroup();
                            break;
                          default:
                            if (isGroupExportMenuValue(value)) {
                              handleGroupExportMenuValue(context, value);
                            } else {
                              onLifecycleAction?.call(value);
                            }
                        }
                      },
                      icon: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(isDark),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.divider(isDark)),
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      itemBuilder: (_) => [
                        // Edit group: admin only. Lets them change name / cover photo.
                        if (canManage && isAdmin && onEditGroup != null)
                          PopupMenuItem(
                            value: 'edit_group',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppColors.textPrimary(isDark),
                                ),
                                const SizedBox(width: 10),
                                const Text('Edit group'),
                              ],
                            ),
                          ),
                        // Default split: admin only, never for a direct group.
                        if (canManage &&
                            isAdmin &&
                            !isDirect &&
                            onDefaultSplit != null)
                          PopupMenuItem(
                            value: 'default_split',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.pie_chart_outline_rounded,
                                  size: 18,
                                  color: AppColors.textPrimary(isDark),
                                ),
                                const SizedBox(width: 10),
                                const Text(AppStrings.defaultSplit),
                              ],
                            ),
                          ),
                        if (canManage && isAdmin) ...lifecycleItems,
                        if (onRecurring != null)
                          PopupMenuItem(
                            value: 'recurring',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.repeat_rounded,
                                  size: 18,
                                  color: AppColors.textPrimary(isDark),
                                ),
                                const SizedBox(width: 10),
                                const Text(AppStrings.recurringExpenses),
                              ],
                            ),
                          ),
                        // Add member: also exposed as a "+ Add" pill next to the
                        // MEMBERS header — kept here for discoverability.
                        if (!isDirect)
                          PopupMenuItem(
                            value: 'add_member',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_add_rounded,
                                  size: 18,
                                  color: AppColors.textPrimary(isDark),
                                ),
                                const SizedBox(width: 10),
                                const Text('Add member'),
                              ],
                            ),
                          ),
                        // Leave group: members only. The admin can't leave
                        // their own group from here — they have to delete it
                        // (or transfer admin first, in a future change).
                        if (canManage && !isAdmin && !isDirect)
                          PopupMenuItem(
                            value: 'leave',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 10),
                                const Text('Leave group'),
                              ],
                            ),
                          ),
                        // Export to Excel: any member can export the ledger.
                        // Placed right before Delete so admins still see Delete
                        // as the final destructive action.
                        if (onExportGroup != null)
                          PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.file_download_outlined,
                                  size: 18,
                                  color: AppColors.textPrimary(isDark),
                                ),
                                const SizedBox(width: 10),
                                const Text(AppStrings.exportToExcel),
                              ],
                            ),
                          ),
                        // CSV + PDF statement sit with Excel (export_group_menu.dart).
                        if (onExportGroup != null)
                          ...buildGroupExportMenuItems(isDark),
                        // Delete group: admin only.
                        if (canManage && isAdmin)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppColors.errorText(isDark),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Delete group',
                                  style: TextStyle(
                                    color: AppColors.errorText(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
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
            child: Icon(icon, size: 18, color: AppColors.textPrimary(isDark)),
          ),
        ),
      ),
    );
  }
}
