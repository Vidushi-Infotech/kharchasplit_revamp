import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/pending_settlements_provider.dart';
import '../../groups/state/groups_provider.dart';

class SettleScreen extends ConsumerStatefulWidget {
  const SettleScreen({
    super.key,
    required this.recipientUserId,
    this.initialGroupId,
    this.initialAmount,
  });

  /// User ID of the person being paid.
  final String recipientUserId;

  /// Optional group to pre-select (e.g. when entering from group detail).
  final String? initialGroupId;

  /// Optional amount to pre-fill (e.g. recipient's balance from group detail).
  /// User can edit before submitting.
  final double? initialAmount;

  @override
  ConsumerState<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends ConsumerState<SettleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  GroupModel? _selectedGroup;
  bool _submitting = false;
  bool _initialGroupApplied = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final group = _selectedGroup;
    final me = ref.read(authProvider).user;
    if (group == null) {
      _toast('Pick a group first.');
      return;
    }
    if (me == null) {
      _toast('You must be signed in.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .create(
            groupId: group.id,
            fromUserId: me.id,
            toUserId: widget.recipientUserId,
            amount: double.parse(_amountController.text.trim()),
            currency: group.currency,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(groupDetailProvider(group.id));
      // Also refresh the pending-settlement sections so the new "Awaiting
      // confirmation" entry shows on the group's Balance tab immediately,
      // without needing a manual reload.
      ref.invalidate(pendingOutgoingSettlementsProvider(group.id));
      ref.invalidate(pendingIncomingSettlementsProvider(group.id));
      if (!mounted) return;
      _toast('Settlement recorded.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Could not settle: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = ref.watch(groupsProvider).value ?? const <GroupModel>[];
    final shared = groups
        .where((g) => g.members.any((m) => m.id == widget.recipientUserId))
        .toList();
    final me = ref.watch(authProvider).user;

    // Apply initialGroupId once, after groups have loaded.
    if (!_initialGroupApplied && widget.initialGroupId != null) {
      final preselect = shared.firstWhereOrNull(
        (g) => g.id == widget.initialGroupId,
      );
      if (preselect != null) {
        _initialGroupApplied = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedGroup == null) {
            setState(() => _selectedGroup = preselect);
          }
        });
      }
    }

    final recipient = _findRecipient(groups, widget.recipientUserId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    recipient == null
                        ? 'Settle up'
                        : 'You’re paying ${recipient.name}',
                    style: AppTextStyles.headline2(isDark),
                  ),
                  if (me != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'From: ${me.name}',
                      style: AppTextStyles.body2(isDark),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (shared.isEmpty)
                    Text(
                      'You don’t share any groups with this person yet.',
                      style: AppTextStyles.body2(isDark),
                    )
                  else
                    DropdownButtonFormField<GroupModel>(
                      initialValue: _selectedGroup,
                      decoration: const InputDecoration(
                        labelText: 'In which group?',
                        border: OutlineInputBorder(),
                      ),
                      items: shared
                          .map(
                            (g) =>
                                DropdownMenuItem(value: g, child: Text(g.name)),
                          )
                          .toList(),
                      onChanged: (g) => setState(() => _selectedGroup = g),
                      validator: (v) => v == null ? 'Pick a group' : null,
                    ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Amount',
                    hint: '0.00',
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixIcon: Icons.currency_rupee_rounded,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) {
                        return 'Enter an amount greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Notes (optional)',
                    hint: 'e.g. Paid via UPI',
                    controller: _notesController,
                    maxLines: 3,
                    minLines: 2,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Record Settlement',
                      onPressed: (_submitting || shared.isEmpty)
                          ? null
                          : _handleSubmit,
                      isLoading: _submitting,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  UserModel? _findRecipient(List<GroupModel> groups, String userId) {
    for (final g in groups) {
      for (final m in g.members) {
        if (m.id == userId) return m;
      }
    }
    return null;
  }
}
