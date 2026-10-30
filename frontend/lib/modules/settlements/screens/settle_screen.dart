import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../expenses/widgets/add_expense_top_bar.dart';
import '../../groups/state/group_balance_helpers.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/record_payment_controller.dart';
import '../state/settle_button_label.dart';
import '../state/settle_group_options_provider.dart';
import '../widgets/record_payment_header.dart';
import '../widgets/record_payment_options.dart';
import '../widgets/settle_upi_section.dart';

/// "Record a payment" (Splitwise style): ✕ title ✓ Save, (you) → (them),
/// "You paid Asha K.", the big green amount, then Today / group / method /
/// note chips and — with `upiPay` — the Pay with UPI block.
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

  /// Null until the user picks one — sent as null rather than a guess.
  SettlementMethod? _method;

  /// The day it was paid; today unless the user picks an earlier one.
  DateTime _paidOn = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    // The button reads "Settle up" or "Record" depending on the amount.
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() => setState(() {});

  /// What you owe the recipient in the chosen group (> 0), from the
  /// group's own balances; the pre-filled amount until it has loaded.
  double? _owedInGroup(GroupModel? group, String? myId) {
    if (group == null || myId == null) return widget.initialAmount;
    final detail = ref.watch(groupDetailProvider(group.id)).value;
    if (detail == null) return widget.initialAmount;
    return groupVisibleDebts(
      myId: myId,
      detail: detail,
    )[widget.recipientUserId];
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// [method] overrides the picker — the UPI flow records with `upi`.
  Future<void> _handleSubmit({SettlementMethod? method}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final group = _selectedGroup;
    final me = ref.read(authProvider).user;
    if (group == null) {
      HapticService.instance.error();
      _toast(AppStrings.pickGroupFirst);
      return;
    }
    if (me == null) {
      _toast('You must be signed in.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(recordPaymentControllerProvider)
          .record(
            group: group,
            fromUserId: me.id,
            toUserId: widget.recipientUserId,
            amount: double.parse(_amountController.text.trim()),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            method: method ?? _method,
            paidOn: _paidOn,
          );
      HapticService.instance.success();
      if (!mounted) return;
      final recipientName = group.members
          .firstWhereOrNull((m) => m.id == widget.recipientUserId)
          ?.name;
      _toast(
        recipientName == null || recipientName.isEmpty
            ? '${AppStrings.paymentRecorded}.'
            : '${AppStrings.paymentRecorded}. $recipientName has been notified.',
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      HapticService.instance.error();
      _toast('Could not record payment: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Includes a non-group (direct) initialGroupId, which isn't in the
    // groups list.
    final shared = ref.watch(
      settleGroupOptionsProvider((
        recipientId: widget.recipientUserId,
        initialGroupId: widget.initialGroupId,
      )),
    );
    final me = ref.watch(authProvider).user;

    // Apply initialGroupId once, after groups have loaded — or the only
    // shared group, so the group chip already reads right.
    if (!_initialGroupApplied &&
        (widget.initialGroupId != null || shared.length == 1)) {
      final preselect = widget.initialGroupId == null
          ? shared.single
          : shared.firstWhereOrNull((g) => g.id == widget.initialGroupId);
      if (preselect != null) {
        _initialGroupApplied = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedGroup == null) {
            setState(() => _selectedGroup = preselect);
          }
        });
      }
    }

    final recipient = _findRecipient(shared, widget.recipientUserId);
    final width = MediaQuery.sizeOf(context).width;
    // Compact < 600 / standard 600–1100 / large > 1100.
    final pad = width < 600 ? 16.0 : (width < 1100 ? 24.0 : 32.0);
    final group = _selectedGroup;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AddExpenseTopBar(
        title: AppStrings.recordAPayment,
        isDark: isDark,
        onClose: () => context.pop(),
        saveEnabled: shared.isNotEmpty,
        saving: _submitting,
        onSave: _handleSubmit,
        onSaveBlocked: () => _toast(AppStrings.noSharedGroups),
        saveLabel: settleButtonLabel(
          owed: _owedInGroup(group, me?.id),
          amount: double.tryParse(_amountController.text.trim()),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RecordPaymentHeader(
                      isDark: isDark,
                      me: me,
                      recipient: recipient,
                      currency: group?.currency ?? '₹',
                      amountController: _amountController,
                    ),
                    const SizedBox(height: 24),
                    RecordPaymentOptions(
                      isDark: isDark,
                      groups: shared,
                      selectedGroup: group,
                      method: _method,
                      paidOn: _paidOn,
                      onPaidOnChanged: (d) => setState(() => _paidOn = d),
                      notesController: _notesController,
                      onGroupChanged: (g) => setState(() => _selectedGroup = g),
                      onMethodChanged: (m) => setState(() => _method = m),
                    ),
                    const SizedBox(height: 24),
                    if (shared.isEmpty)
                      Text(
                        AppStrings.noSharedGroups,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body2(isDark),
                      ),
                    if (group != null && !_submitting)
                      SettleUpiSection(
                        recipientUserId: widget.recipientUserId,
                        recipientName: recipient?.name ?? '',
                        currency: group.currency,
                        groupName: group.name,
                        amountController: _amountController,
                        onConfirmedPaid: () =>
                            _handleSubmit(method: SettlementMethod.upi),
                      ),
                  ],
                ),
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
