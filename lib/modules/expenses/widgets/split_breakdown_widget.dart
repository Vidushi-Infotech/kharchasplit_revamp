import 'package:flutter/material.dart';
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

  const SplitBreakdownWidget({
    Key? key,
    required this.splitType,
    required this.totalAmount,
    required this.members,
    required this.splits,
    required this.includedMemberIds,
    required this.onSplitsChanged,
    required this.onIncludedMembersChanged,
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
      case SplitType.adjustment:
        return '0.00';
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
      case SplitType.adjustment:
        if (includedSum.abs() < 0.01) {
          return (label: '✓ Balanced (±0)', color: AppColors.success);
        } else if (includedSum > 0) {
          return (label: '+₹${includedSum.toStringAsFixed(2)} over', color: AppColors.warning);
        } else {
          return (label: '-₹${(-includedSum).toStringAsFixed(2)} under', color: AppColors.warning);
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
            // Footer with total
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Included',
                    style: AppTextStyles.body2(isDark),
                  ),
                  Text(
                    widget.splitType == SplitType.percentage
                        ? '${_getTotalIncluded().toStringAsFixed(1)}%'
                        : widget.splitType == SplitType.shares
                            ? '${_getTotalIncluded().toStringAsFixed(0)} shares'
                            : '₹${_getTotalIncluded().toStringAsFixed(2)}',
                    style: AppTextStyles.body2(isDark)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
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

    return GestureDetector(
      onTap: () => _toggleMember(member.id),
      child: Container(
        color: isIncluded
            ? Colors.transparent
            : AppColors.textSecondary(isDark).withValues(alpha: 0.05),
        padding: const EdgeInsets.all(12),
        child: Row(
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
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.brand.withValues(alpha: 0.2),
            child: Text(
              member.name.split(' ').map((e) => e[0]).join().toUpperCase(),
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            flex: 1,
            child: Text(
              member.name,
              style: AppTextStyles.body2(isDark).copyWith(
                color: isIncluded
                    ? AppColors.textPrimary(isDark)
                    : AppColors.textSecondary(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              onChanged: (_) => _updateSplits(),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
