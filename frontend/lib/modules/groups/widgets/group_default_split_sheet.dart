import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import 'group_default_split_controller.dart';

/// Opens the admin-only "Default split" editor for [group] (never for a
/// direct group — the caller hides the entry).
Future<void> showGroupDefaultSplitSheet(BuildContext context, GroupModel group) {
  return showAdaptiveSheet<void>(
    context: context,
    size: AdaptiveSheetSize.medium,
    // Above the floating tab bar when the group screen is in the tab shell.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GroupDefaultSplitSheet(group: group),
  );
}

class GroupDefaultSplitSheet extends ConsumerStatefulWidget {
  const GroupDefaultSplitSheet({super.key, required this.group});
  final GroupModel group;

  @override
  ConsumerState<GroupDefaultSplitSheet> createState() =>
      _GroupDefaultSplitSheetState();
}

class _GroupDefaultSplitSheetState
    extends ConsumerState<GroupDefaultSplitSheet> {
  late DefaultSplitType _type;
  late final List<String> _ids;
  final Map<String, TextEditingController> _controllers = {};
  // Local UI flag only: disables the buttons while the PUT runs.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ids = [for (final m in widget.group.members) m.id];
    final start = initialDefaultSplit(widget.group, _ids);
    _type = start.type;
    for (final id in _ids) {
      _controllers[id] = TextEditingController(text: _fmt(start.values[id]))
        ..addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double? v) {
    final x = v ?? 0;
    return x == x.roundToDouble() ? x.toStringAsFixed(0) : '$x';
  }

  Map<String, double> get _values => {
        for (final id in _ids)
          id: double.tryParse(_controllers[id]!.text.trim()) ?? 0,
      };

  void _switchType(DefaultSplitType type) {
    if (type == _type) return;
    final equal = equalValues(type, _ids);
    setState(() => _type = type);
    for (final id in _ids) {
      _controllers[id]!.text = _fmt(equal[id]);
    }
  }

  Future<void> _save({bool clear = false}) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final error = await saveDefaultSplit(
      ref,
      widget.group.id,
      type: clear ? null : _type,
      values: clear ? null : _values,
    );
    if (error == null) {
      HapticService.instance.success();
      navigator.pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (clear
                  ? AppStrings.defaultSplitCleared
                  : AppStrings.defaultSplitSaved),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final values = _values;
    final error = defaultSplitError(_type, values);
    final total = _fmt(
      (defaultSplitTotal(values) * 100).roundToDouble() / 100,
    );
    final isPct = _type == DefaultSplitType.percentage;
    final secondary = AppColors.textSecondary(isDark);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Material(
          color: AppColors.background(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text(
                    AppStrings.defaultSplit,
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    AppStrings.defaultSplitHint,
                    style: AppTextStyles.caption(
                      isDark,
                    ).copyWith(color: secondary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SegmentedButton<DefaultSplitType>(
                    segments: const [
                      ButtonSegment(
                        value: DefaultSplitType.percentage,
                        label: Text(AppStrings.percentage),
                        icon: Icon(Icons.percent_rounded),
                      ),
                      ButtonSegment(
                        value: DefaultSplitType.shares,
                        label: Text(AppStrings.shares),
                        icon: Icon(Icons.pie_chart_outline_rounded),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: _saving
                        ? null
                        : (s) => _switchType(s.first),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    itemCount: widget.group.members.length,
                    itemBuilder: (_, i) {
                      final m = widget.group.members[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            AvatarWidget(
                              name: m.name,
                              imageUrl: m.avatarUrl,
                              radius: 16,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                m.name.isEmpty ? m.phone : m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body2(isDark),
                              ),
                            ),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: _controllers[m.id],
                                enabled: !_saving,
                                textAlign: TextAlign.end,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d{0,6}(\.\d{0,2})?'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  isDense: true,
                                  suffixText: isPct ? '%' : null,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    error ??
                        (isPct
                            ? AppStrings.percentTotal(total)
                            : AppStrings.sharesTotal(total)),
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: error != null
                          ? AppColors.errorText(isDark)
                          : AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (error != null && isPct)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                    child: Text(
                      AppStrings.percentTotal(total),
                      style: AppTextStyles.caption(
                        isDark,
                      ).copyWith(color: secondary),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Row(
                    children: [
                      if (widget.group.defaultSplit != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _save(clear: true),
                            child: const Text(AppStrings.clearDefaultSplit),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.tealDark,
                          ),
                          onPressed: _saving || error != null ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(AppStrings.save),
                        ),
                      ),
                    ],
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
