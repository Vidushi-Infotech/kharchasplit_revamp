import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

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
  }) : super(key: key);

  @override
  State<SplitBreakdownWidget> createState() => _SplitBreakdownWidgetState();
}

class _SplitBreakdownWidgetState extends State<SplitBreakdownWidget> {
  late Map<String, TextEditingController> _controllers;
  late bool _isExpanded;
  late TextEditingController _searchController;
  late Set<String> _localIncludedMembers;

  @override
  void initState() {
    super.initState();
    _isExpanded = true;
    _searchController = TextEditingController();
    _controllers = {};

    // Initialize with all members included by default
    _localIncludedMembers = widget.includedMemberIds.isEmpty
        ? Set<String>.from(widget.members.map((m) => m.id))
        : Set<String>.from(widget.includedMemberIds);

    for (final member in widget.members) {
      final value = widget.splits[member.id] ?? 0;
      _controllers[member.id] = TextEditingController(
        text: value > 0 ? value.toString() : '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  String _getInputHint(SplitType type) {
    switch (type) {
      case SplitType.exact:
        return '0.00';
      case SplitType.percentage:
        return '0';
      case SplitType.shares:
        return '1';
      default:
        return '';
    }
  }

  String _getInputSuffix(SplitType type) {
    switch (type) {
      case SplitType.percentage:
        return '%';
      case SplitType.shares:
        return 'shares';
      default:
        return '';
    }
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
    });
    widget.onIncludedMembersChanged(_localIncludedMembers);
    _updateSplits();
  }

  void _selectAll() {
    setState(() {
      _localIncludedMembers = Set<String>.from(widget.members.map((m) => m.id));
    });
    widget.onIncludedMembersChanged(_localIncludedMembers);
    _updateSplits();
  }

  void _deselectAll() {
    setState(() {
      _localIncludedMembers.clear();
    });
    widget.onIncludedMembersChanged(_localIncludedMembers);
    _updateSplits();
  }

  ({String label, Color color}) _getValidationStatus() {
    final includedSum = widget.splits.entries
        .where((e) => _localIncludedMembers.contains(e.key))
        .fold<double>(0, (sum, e) => sum + e.value);

    switch (widget.splitType) {
      case SplitType.exact:
        final diff = widget.totalAmount - includedSum;
        if ((diff).abs() < 0.01) {
          return (label: '✓ Balanced', color: AppColors.success);
        } else if (diff > 0) {
          return (label: '₹${diff.toStringAsFixed(2)} remaining', color: AppColors.warning);
        } else {
          return (label: 'Over by ₹${(-diff).toStringAsFixed(2)}', color: AppColors.warning);
        }
      case SplitType.percentage:
        final diff = 100 - includedSum;
        if ((diff).abs() < 0.01) {
          return (label: '✓ Balanced (100%)', color: AppColors.success);
        } else if (diff > 0) {
          return (label: '${diff.toStringAsFixed(1)}% remaining', color: AppColors.warning);
        } else {
          return (label: 'Over by ${(-diff).toStringAsFixed(1)}%', color: AppColors.warning);
        }
      case SplitType.shares:
        if (includedSum > 0) {
          return (label: '✓ Valid', color: AppColors.success);
        } else {
          return (label: 'No shares set', color: AppColors.warning);
        }
      default:
        return (label: '✓ Balanced', color: AppColors.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _getValidationStatus();
    final searchQuery = _searchController.text.toLowerCase();
    final filteredMembers = widget.members
        .where((m) => m.name.toLowerCase().contains(searchQuery))
        .toList();
    final includedMembers = _localIncludedMembers.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Header (collapsible)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background(isDark),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Split Breakdown ($includedMembers members)',
                          style: AppTextStyles.body2(isDark)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.label,
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: status.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),

          // Content (expandable)
          if (_isExpanded) ...[
            const Divider(height: 1),
            // Search box
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: TextStyle(color: AppColors.textSecondary(isDark)),
                  prefixIcon: Icon(Icons.search, color: AppColors.brand, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: Icon(Icons.close, color: AppColors.brand, size: 20),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            // Select All / Deselect All buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectAll,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Select All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _deselectAll,
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Deselect All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Filtered members list
            Column(
              children: filteredMembers
                  .map((member) => _buildMemberRow(isDark, member))
                  .toList(),
            ),
            const Divider(height: 1),
            // Footer with total + (Unequally only) remaining + helper hint
            _buildFooter(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final total = _getTotalIncluded();

    String totalLabel;
    String totalValue;
    switch (widget.splitType) {
      case SplitType.percentage:
        totalLabel = 'Total assigned';
        totalValue = '${total.toStringAsFixed(1)}% / 100%';
        break;
      case SplitType.shares:
        totalLabel = 'Total shares';
        totalValue = '${total.toStringAsFixed(0)} shares';
        break;
      case SplitType.exact:
        final pct = widget.totalAmount > 0
            ? (total / widget.totalAmount * 100)
            : 0.0;
        totalLabel = 'Total assigned';
        totalValue =
            '₹${total.toStringAsFixed(2)}  ·  ${pct.toStringAsFixed(1)}%';
        break;
      case SplitType.equal:
        totalLabel = 'Total Included';
        totalValue = '₹${total.toStringAsFixed(2)}';
        break;
    }

    final children = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(totalLabel, style: AppTextStyles.body2(isDark)),
          Text(
            totalValue,
            style: AppTextStyles.body2(isDark)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ];

    // For Unequally (Exact) — show the remaining-to-assign line + a helper.
    if (widget.splitType == SplitType.exact) {
      final remaining = widget.totalAmount - total;
      Color rowColor;
      String rowLabel;
      String rowValue;
      if (remaining.abs() < 0.01) {
        rowColor = AppColors.success;
        rowLabel = '✓ Balanced';
        rowValue = '₹0.00';
      } else if (remaining > 0) {
        rowColor = AppColors.warning;
        rowLabel = '⚠️ Remaining to assign';
        rowValue = '₹${remaining.toStringAsFixed(2)}';
      } else {
        rowColor = AppColors.warning;
        rowLabel = '⚠️ Over by';
        rowValue = '₹${(-remaining).toStringAsFixed(2)}';
      }

      children.addAll([
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              rowLabel,
              style: AppTextStyles.body2(isDark).copyWith(
                color: rowColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              rowValue,
              style: AppTextStyles.body2(isDark).copyWith(
                color: rowColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: AppColors.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Manually assign each amount. Sum must equal ₹${widget.totalAmount.toStringAsFixed(2)}.',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  double _getTotalIncluded() {
    return widget.splits.entries
        .where((e) => _localIncludedMembers.contains(e.key))
        .fold<double>(0, (sum, e) => sum + e.value);
  }

  Widget _buildMemberRow(bool isDark, UserModel member) {
    final isIncluded = _localIncludedMembers.contains(member.id);
    final controller = _controllers[member.id]!;
    final value = widget.splits[member.id] ?? 0;

    // For Unequally (Exact): show % of total + "Owes ₹X" caption under name.
    String? statusCaption;
    String? percentCaption;
    if (widget.splitType == SplitType.exact && isIncluded) {
      if (widget.totalAmount > 0) {
        final pct = value / widget.totalAmount * 100;
        percentCaption = pct == pct.roundToDouble()
            ? '${pct.toStringAsFixed(0)}% of total'
            : '${pct.toStringAsFixed(1)}% of total';
      }
      statusCaption = value > 0
          ? 'Owes ₹${value.toStringAsFixed(2)}'
          : 'Not yet assigned';
    }

    return GestureDetector(
      onTap: () => _toggleMember(member.id),
      child: Container(
        color: isIncluded
            ? Colors.transparent
            : AppColors.textSecondary(isDark).withValues(alpha: 0.05),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: isIncluded,
              tristate: false,
              onChanged: (_) => _toggleMember(member.id),
              activeColor: AppColors.brand,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          const SizedBox(width: 8),
          // Avatar
          AvatarWidget(
            name: member.name,
            imageUrl: member.avatarUrl,
            radius: 16,
          ),
          const SizedBox(width: 8),
          // Name + (Unequally only) status caption
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.currentUserId != null &&
                          member.id == widget.currentUserId
                      ? '${member.name} (Me)'
                      : member.name,
                  style: AppTextStyles.body2(isDark).copyWith(
                    color: isIncluded
                        ? AppColors.textPrimary(isDark)
                        : AppColors.textSecondary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusCaption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    statusCaption,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: value > 0
                          ? AppColors.success
                          : AppColors.textSecondary(isDark),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (percentCaption != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    percentCaption,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Input field
          Expanded(
            flex: 1,
            child: TextField(
              controller: controller,
              enabled: isIncluded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.body2(isDark).copyWith(
                color: isIncluded
                    ? AppColors.textPrimary(isDark)
                    : AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                prefixText: widget.splitType == SplitType.exact ? '₹' : null,
                suffixText: _getInputSuffix(widget.splitType),
                hintText: _getInputHint(widget.splitType),
                hintStyle: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppColors.divider(isDark),
                  ),
                ),
              ),
              onChanged: (value) {
                if (widget.splitType == SplitType.percentage &&
                    _localIncludedMembers.length == 2) {
                  final entered = double.tryParse(value) ?? 0;
                  final clamped = entered.clamp(0, 100).toDouble();
                  // The other-of-two should always exist when length==2, but
                  // a stale set during a rebuild could leave us empty — guard
                  // with firstWhereOrNull rather than crash.
                  final otherId = _localIncludedMembers
                      .firstWhereOrNull((id) => id != member.id);
                  final otherController =
                      otherId == null ? null : _controllers[otherId];
                  if (otherController != null) {
                    final remaining = (100 - clamped);
                    final formatted = remaining == remaining.toInt()
                        ? remaining.toInt().toString()
                        : remaining.toStringAsFixed(1);
                    otherController.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                }
                _updateSplits();
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
