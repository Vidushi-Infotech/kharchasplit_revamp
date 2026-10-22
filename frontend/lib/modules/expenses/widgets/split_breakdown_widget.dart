import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';
import 'split_member_row.dart';

class SplitBreakdownWidget extends StatefulWidget {
  final SplitType splitType;
  final double totalAmount;
  final List<UserModel> members;
  final Map<String, double> splits;
  final Set<String> includedMemberIds;
  final Function(Map<String, double>) onSplitsChanged;
  final Function(Set<String>) onIncludedMembersChanged;

  /// Id of the signed-in user. When non-null, that member's row shows
  /// "Name (Me)" so users can spot themselves at a glance.
  final String? currentUserId;

  /// Symbol the amounts are in (the form's entry currency).
  final String currency;

  const SplitBreakdownWidget({
    Key? key,
    required this.splitType,
    required this.totalAmount,
    required this.members,
    required this.splits,
    required this.includedMemberIds,
    required this.onSplitsChanged,
    required this.onIncludedMembersChanged,
    this.currentUserId,
    this.currency = '₹',
  }) : super(key: key);

  @override
  State<SplitBreakdownWidget> createState() => _SplitBreakdownWidgetState();
}

class _SplitBreakdownWidgetState extends State<SplitBreakdownWidget> {
  late Map<String, TextEditingController> _controllers;
  late TextEditingController _searchController;
  late Set<String> _localIncludedMembers;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _controllers = {};

    // Initialize with all members included by default
    _localIncludedMembers = widget.includedMemberIds.isEmpty
        ? Set<String>.from(widget.members.map((m) => m.id))
        : Set<String>.from(widget.includedMemberIds);

    for (final member in widget.members) {
      final value = widget.splits[member.id] ?? 0;
      _controllers[member.id] = TextEditingController(
        // Format on first view too — otherwise the raw equal-split double
        // (e.g. 6.77777777…) shows until the user switches modes and back.
        text: value > 0 ? _formatNum(value) : '',
      );
    }
  }

  @override
  void didUpdateWidget(covariant SplitBreakdownWidget old) {
    super.didUpdateWidget(old);
    // Who's in can also change from outside (e.g. "Split equally" on the
    // group-default hint) — follow it before re-seeding the inputs.
    if (!setEquals(old.includedMemberIds, widget.includedMemberIds)) {
      _localIncludedMembers = widget.includedMemberIds.isEmpty
          ? Set<String>.from(widget.members.map((m) => m.id))
          : Set<String>.from(widget.includedMemberIds);
      // e.g. the "All" box on the Split options bar: refresh the per-head
      // amounts for the new count.
      if (widget.splitType == SplitType.equal &&
          old.splitType == SplitType.equal) {
        _applyEqualShares();
      }
    }
    // When the user switches split method, the per-member inputs must not
    // carry the previous method's numbers (e.g. the equal-split ₹ amounts
    // showing up as "666%" after switching to percentage).
    if (old.splitType != widget.splitType) {
      _resetForSplitType();
    } else if (widget.splitType == SplitType.equal &&
        old.totalAmount != widget.totalAmount) {
      // Amount changed while in equal mode → refresh the per-head display.
      _applyEqualShares();
    }
  }

  /// In equal mode, fill each included member's field with the live equal
  /// share (totalAmount / includedCount) and blank out excluded members.
  /// Re-run whenever the amount or the included set changes so the displayed
  /// per-head amount stays correct (e.g. deselecting one of 9 recalculates
  /// for the remaining 8).
  void _applyEqualShares() {
    final included = _localIncludedMembers;
    final share = included.isEmpty ? 0.0 : widget.totalAmount / included.length;
    for (final member in widget.members) {
      final c = _controllers[member.id];
      if (c == null) continue;
      c.text = (included.contains(member.id) && share > 0)
          ? _formatNum(share)
          : '';
    }
  }

  /// Re-seed the input fields for the newly selected split method:
  ///   - equal  → show each included member's equal share (informational)
  ///   - others → clear to empty so the user starts from zero
  void _resetForSplitType() {
    if (widget.splitType == SplitType.equal) {
      _applyEqualShares();
    } else {
      for (final c in _controllers.values) {
        c.text = '';
      }
    }
    // Push the reset splits up after this frame — mutating the parent
    // provider synchronously during a rebuild is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateSplits();
    });
  }

  String _formatNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  void _setControllerNumber(TextEditingController c, double v) {
    final formatted = v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);
    c.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Percentage convenience: as the user types a %, auto-balance the rest to
  /// total 100. With exactly two members, the other member gets the remainder;
  /// with more than two, the LAST included member absorbs the remainder.
  void _autofillPercentage({required String editedMemberId}) {
    final included = widget.members
        .where((m) => _localIncludedMembers.contains(m.id))
        .toList();
    if (included.length < 2) return;

    if (included.length == 2) {
      final entered =
          (double.tryParse(_controllers[editedMemberId]?.text ?? '') ?? 0)
              .clamp(0, 100)
              .toDouble();
      final otherId = included
          .firstWhereOrNull((m) => m.id != editedMemberId)
          ?.id;
      final other = otherId == null ? null : _controllers[otherId];
      if (other != null) _setControllerNumber(other, 100 - entered);
      return;
    }

    // > 2 members — keep the last one as the running balancer.
    final lastId = included.last.id;
    if (editedMemberId == lastId) return; // don't fight the user editing it
    double sumOthers = 0;
    for (final m in included) {
      if (m.id == lastId) continue;
      sumOthers += double.tryParse(_controllers[m.id]?.text ?? '') ?? 0;
    }
    final remaining = (100 - sumOthers).clamp(0, 100).toDouble();
    final last = _controllers[lastId];
    if (last != null) _setControllerNumber(last, remaining);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _updateSplits() {
    final newSplits = <String, double>{};
    for (final member in widget.members) {
      final text = _controllers[member.id]?.text ?? '';
      final value = double.tryParse(text) ?? 0;
      newSplits[member.id] = value;
    }
    widget.onSplitsChanged(newSplits);
  }

  void _toggleMember(String memberId) {
    setState(() {
      if (_localIncludedMembers.contains(memberId)) {
        _localIncludedMembers.remove(memberId);
        _controllers[memberId]?.text = '';
      } else {
        _localIncludedMembers.add(memberId);
      }
      // Equal mode: recompute everyone's per-head amount for the new count so
      // the displayed shares stay correct (and a re-selected member doesn't
      // show ₹0).
      if (widget.splitType == SplitType.equal) {
        _applyEqualShares();
      }
    });
    widget.onIncludedMembersChanged(_localIncludedMembers);
    _updateSplits();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchQuery = _searchController.text.toLowerCase();
    final filteredMembers = widget.members
        .where((m) => m.name.toLowerCase().contains(searchQuery))
        .toList();

    // Flat rows (Splitwise style); the running total / "left" lives in the
    // Split options bottom bar. Search only pays off in big groups.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.members.length > 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(color: AppColors.textSecondary(isDark)),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.brand,
                  size: 20,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredMembers.length,
          itemBuilder: (_, i) {
            final m = filteredMembers[i];
            return SplitMemberRow(
              member: m,
              controller: _controllers[m.id]!,
              included: _localIncludedMembers.contains(m.id),
              value: widget.splits[m.id] ?? 0,
              splitType: widget.splitType,
              totalAmount: widget.totalAmount,
              currency: widget.currency,
              isMe: m.id == widget.currentUserId,
              onToggle: () => _toggleMember(m.id),
              onChanged: () {
                if (widget.splitType == SplitType.percentage) {
                  _autofillPercentage(editedMemberId: m.id);
                }
                _updateSplits();
              },
            );
          },
        ),
      ],
    );
  }
}
