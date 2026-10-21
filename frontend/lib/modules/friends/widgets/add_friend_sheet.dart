import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/registered_users_provider.dart';
import '../../groups/widgets/contacts_picker_sheet.dart';
import '../state/add_friend_provider.dart';
import 'add_friend_result.dart';

/// Opens the "Add friend" sheet (Friends tab app bar / web header / empty
/// state). On success it closes and opens the friend's detail page.
Future<void> showAddFriendSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Root navigator: from a tab screen the shell's floating bottom bar
    // would otherwise cover the bottom of the sheet.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // A full-width sheet on a 1920px window reads as a phone sheet.
    constraints: context.widthTier.isWebTier
        ? const BoxConstraints(maxWidth: 560)
        : null,
    builder: (_) => const AddFriendSheet(),
  );
}

class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key});

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();

  // Local UI hint only — shown when several contacts were picked.
  String? _pickHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _find() {
    setState(() => _pickHint = null);
    ref
        .read(addFriendControllerProvider.notifier)
        .lookup(_phoneController.text);
  }

  Future<void> _pickContact() async {
    final selfPhone = ref.read(authProvider).user?.phone ?? '';
    final picked = await showContactsPicker(
      context,
      registeredCtaLabel: 'Select',
      unregisteredCtaLabel: 'Select',
      selfPhones: selfPhone.isEmpty ? const [] : [selfPhone],
    );
    if (!mounted || picked.isEmpty) return;
    if (picked.length > 1) {
      setState(() => _pickHint = AppStrings.pickOnePerson);
      return;
    }
    final phones = picked.first.phones;
    if (phones.isEmpty) return;
    _phoneController.text = normalizePhone(phones.first.number);
    _find();
  }

  Future<void> _add() async {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final id = await ref.read(addFriendControllerProvider.notifier).add();
    if (id == null || !mounted) return;
    navigator.pop();
    router.push('/home/friends/$id');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(addFriendControllerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.addFriend, style: AppTextStyles.headline3(isDark)),
            const SizedBox(height: 4),
            Text(
              AppStrings.addFriendHint,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PhoneInput(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    isDark: isDark,
                    enabled: !state.busy,
                    onChanged: (_) {
                      if (state.status != AddFriendStatus.idle) {
                        ref.read(addFriendControllerProvider.notifier).reset();
                      }
                    },
                    onSubmitted: (_) => _find(),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Find by phone number',
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: state.busy ? null : _find,
                    child: const Text(AppStrings.findFriend),
                  ),
                ),
              ],
            ),
            // Device contacts aren't available in the browser.
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: state.busy ? null : _pickContact,
                  icon: const Icon(Icons.contacts_outlined, size: 18),
                  label: const Text(AppStrings.pickFromContacts),
                ),
              ),
            ],
            if (_pickHint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _pickHint!,
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 12),
            AddFriendResult(state: state, onAdd: _add),
          ],
        ),
      ),
    );
  }
}

/// "+91 | 98765 43210" — same look as the login phone field.
class _PhoneInput extends StatelessWidget {
  const _PhoneInput({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyles.body1(
      isDark,
    ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.4);
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '+91',
              style: textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.divider(isDark)),
          Expanded(
            child: Semantics(
              label: 'Mobile number',
              textField: true,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.search,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: textStyle,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  hintText: '98765 43210',
                  hintStyle: textStyle.copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
