import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/groups/groups_repository.dart';
import '../state/group_detail_provider.dart';
import '../state/group_lifecycle_controller.dart';

/// "Simplify group debts" switch row for Group settings. Only an admin can
/// flip it ([canEdit]); everyone else sees the current state.
class GroupSimplifyDebtsTile extends ConsumerStatefulWidget {
  const GroupSimplifyDebtsTile({
    super.key,
    required this.groupId,
    required this.canEdit,
  });

  final String groupId;
  final bool canEdit;

  @override
  ConsumerState<GroupSimplifyDebtsTile> createState() =>
      _GroupSimplifyDebtsTileState();
}

class _GroupSimplifyDebtsTileState
    extends ConsumerState<GroupSimplifyDebtsTile> {
  // Local UI flag only — the switch is disabled while the PUT is in flight.
  bool _saving = false;

  Future<void> _toggle(bool enabled) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await ref
          .read(groupLifecycleControllerProvider)
          .setSimplifyDebts(widget.groupId, enabled: enabled);
      HapticService.instance.success();
      message = enabled
          ? AppStrings.simplifyDebtsTurnedOn
          : AppStrings.simplifyDebtsTurnedOff;
    } on GroupsApiException catch (e) {
      // 403 for non-admins, archived-group rules… — show it verbatim.
      message = e.message;
    } catch (e) {
      message = 'Could not change the setting: $e';
    }
    if (mounted) setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Reflects the refetched group after a successful toggle.
    final enabled = ref.watch(
      groupDetailProvider(
        widget.groupId,
      ).select((d) => d.value?.group.simplifyDebts ?? false),
    );

    return Semantics(
      toggled: enabled,
      label: AppStrings.simplifyGroupDebts,
      child: SwitchListTile.adaptive(
        value: enabled,
        activeTrackColor: AppColors.brand,
        onChanged: _saving || !widget.canEdit ? null : _toggle,
        secondary: _saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_fix_high_rounded, color: AppColors.brand),
        title: Text(
          AppStrings.simplifyGroupDebts,
          style: AppTextStyles.body1(
            isDark,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.canEdit
                ? AppStrings.simplifyGroupDebtsHint
                : '${AppStrings.simplifyGroupDebtsHint}\n'
                      '${AppStrings.adminOnlySetting}',
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
          ),
        ),
      ),
    );
  }
}
