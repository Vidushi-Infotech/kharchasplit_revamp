import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/group_model.dart';
import '../state/group_detail_provider.dart';
import '../state/group_lifecycle_controller.dart';

/// ⋮-menu value for the admin-only "Simplify group debts" entry. Routed
/// through the top bar's lifecycle callback like the archive entries.
const simplifyDebtsMenuValue = 'settings_simplify_debts';

/// "Simplify group debts · On/Off" entry for the ⋮ menu (admins only, and
/// only while the `simplifyDebts` flag is on — the caller decides).
PopupMenuEntry<String> buildSimplifyDebtsMenuItem(
  bool isDark,
  GroupModel group,
) {
  return PopupMenuItem(
    value: simplifyDebtsMenuValue,
    child: Row(
      children: [
        Icon(
          Icons.auto_fix_high_rounded,
          size: 18,
          color: AppColors.textPrimary(isDark),
        ),
        const SizedBox(width: 10),
        const Flexible(child: Text(AppStrings.simplifyGroupDebts)),
        const SizedBox(width: 8),
        Text(
          group.simplifyDebts ? AppStrings.on : AppStrings.off,
          style: AppTextStyles.caption(
            isDark,
          ).copyWith(color: AppColors.textSecondary(isDark)),
        ),
      ],
    ),
  );
}

/// Opens the switch sheet for [groupId].
Future<void> showSimplifyDebtsSheet(BuildContext context, String groupId) {
  return showAdaptiveSheet<void>(
    context: context,
    size: AdaptiveSheetSize.small,
    useRootNavigator: true,
    builder: (_) => _SimplifyDebtsSheet(groupId: groupId),
  );
}

class _SimplifyDebtsSheet extends ConsumerStatefulWidget {
  const _SimplifyDebtsSheet({required this.groupId});
  final String groupId;

  @override
  ConsumerState<_SimplifyDebtsSheet> createState() =>
      _SimplifyDebtsSheetState();
}

class _SimplifyDebtsSheetState extends ConsumerState<_SimplifyDebtsSheet> {
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

    return Material(
      color: AppColors.surface(isDark),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                toggled: enabled,
                label: AppStrings.simplifyGroupDebts,
                child: SwitchListTile.adaptive(
                  value: enabled,
                  activeTrackColor: AppColors.brand,
                  onChanged: _saving ? null : _toggle,
                  secondary: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.auto_fix_high_rounded,
                          color: AppColors.brand,
                        ),
                  title: Text(
                    AppStrings.simplifyGroupDebts,
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      AppStrings.simplifyGroupDebtsHint,
                      style: AppTextStyles.caption(
                        isDark,
                      ).copyWith(color: AppColors.textSecondary(isDark)),
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
