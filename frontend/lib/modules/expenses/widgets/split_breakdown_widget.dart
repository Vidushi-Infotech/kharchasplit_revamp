import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

/// Per-member split breakdown for non-equal split types (exact, percentage,
/// shares). Redesigned to match the 21st.dev minimal aesthetic used across
/// the rest of the redesigned screens.
///
/// Public API (callbacks + props) is unchanged.
class SplitBreakdownWidget extends StatefulWidget {
  const SplitBreakdownWidget({
    super.key,
    required this.splitType,
    required this.totalAmount,
    required this.members,
    required this.splits,
    required this.includedMemberIds,
    required this.onSplitsChanged,
    required this.onIncludedMembersChanged,
  });

  final SplitType splitType;
  final double totalAmount;
  final List<UserModel> members;
  final Map<String, double> splits;
  final Set<String> includedMemberIds;
  final ValueChanged<Map<String, double>> onSplitsChanged;
  final ValueChanged<Set<String>> onIncludedMembersChanged;

  @override
  State<SplitBreakdownWidget> createState() => _SplitBreakdownWidgetState();
}

class _SplitBreakdownWidgetState extends State<SplitBreakdownWidget> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _searchController;
  late Set<String> _local;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _controllers = {};

    _local = widget.includedMemberIds.isEmpty
        ? widget.members.map((m) => m.id).toSet()
        : Set<String>.from(widget.includedMemberIds);

    for (final m in widget.members) {
      final v = widget.splits[m.id] ?? 0;
      _controllers[m.id] =
          TextEditingController(text: v > 0 ? _formatNum(v) : '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _hintFor(SplitType t) {
    switch (t) {
      case SplitType.exact:
        return '0.00';
      case SplitType.percentage:
        return '0';
      case SplitType.shares:
        return '1';
      case SplitType.equal:
        return '';
    }
  }

  String _suffixFor(SplitType t) {
    switch (t) {
      case SplitType.percentage:
        return '%';
      case SplitType.shares:
        return 'sh';
      case SplitType.exact:
      case SplitType.equal:
        return '';
    }
  }

  void _emitSplits() {
    final next = <String, double>{};
    for (final m in widget.members) {
      final text = _controllers[m.id]?.text ?? '';
      next[m.id] = double.tryParse(text) ?? 0;
    }
    widget.onSplitsChanged(next);
  }

  void _toggleMember(String id) {
    setState(() {
      if (_local.contains(id)) {
        _local.remove(id);
        _controllers[id]?.text = '';
      } else {
        _local.add(id);
      }
    });
    widget.onIncludedMembersChanged(_local);
    _emitSplits();
  }

  void _selectAll() {
    setState(() => _local = widget.members.map((m) => m.id).toSet());
    widget.onIncludedMembersChanged(_local);
    _emitSplits();
  }

  void _clearAll() {
    setState(() {
      _local.clear();
      for (final c in _controllers.values) {
        c.text = '';
      }
    });
    widget.onIncludedMembersChanged(_local);
    _emitSplits();
  }

  double _includedTotal() {
    return widget.splits.entries
        .where((e) => _local.contains(e.key))
        .fold<double>(0, (s, e) => s + e.value);
  }

  ({String label, _StatusKind kind}) _status() {
    final total = _includedTotal();
    switch (widget.splitType) {
      case SplitType.exact:
        final diff = widget.totalAmount - total;
        if (diff.abs() < 0.01) {
          return (label: 'Balanced', kind: _StatusKind.ok);
        }
        if (diff > 0) {
          return (
            label: '₹${diff.toStringAsFixed(2)} left',
            kind: _StatusKind.warn,
          );
        }
        return (
          label: 'Over by ₹${(-diff).toStringAsFixed(2)}',
          kind: _StatusKind.warn,
        );
      case SplitType.percentage:
        final diff = 100 - total;
        if (diff.abs() < 0.01) {
          return (label: '100%', kind: _StatusKind.ok);
        }
        if (diff > 0) {
          return (
            label: '${diff.toStringAsFixed(1)}% left',
            kind: _StatusKind.warn,
          );
        }
        return (
          label: 'Over by ${(-diff).toStringAsFixed(1)}%',
          kind: _StatusKind.warn,
        );
      case SplitType.shares:
        if (total > 0) {
          return (label: 'Valid', kind: _StatusKind.ok);
        }
        return (label: 'No shares', kind: _StatusKind.warn);
      case SplitType.equal:
        return (label: 'Balanced', kind: _StatusKind.ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _status();
    final q = _searchController.text.toLowerCase();
    final filtered = q.isEmpty
        ? widget.members
        : widget.members.where((m) => m.name.toLowerCase().contains(q)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          children: [
            Expanded(
              child: Text(
                'BREAKDOWN',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  fontSize: 11,
                ),
              ),
            ),
            _StatusChip(status: status, isDark: isDark),
          ],
        ),
        const SizedBox(height: 10),

        // Main card
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Collapsible row: member count + select all / chevron
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_local.length} of ${widget.members.length} included',
                            style: AppTextStyles.body2(isDark).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _local.length == widget.members.length
                              ? _clearAll
                              : _selectAll,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.tealDark,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _local.length == widget.members.length
                                ? 'Clear'
                                : 'Select all',
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.tealDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_expanded) ...[
                _hairline(isDark),

                // Search (only if more than a few members)
                if (widget.members.length > 4) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: _SearchField(
                      controller: _searchController,
                      isDark: isDark,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  _hairline(isDark),
                ],

                // Member rows
                for (int i = 0; i < filtered.length; i++) ...[
                  _MemberRow(
                    isDark: isDark,
                    member: filtered[i],
                    splitType: widget.splitType,
                    totalAmount: widget.totalAmount,
                    value: widget.splits[filtered[i].id] ?? 0,
                    included: _local.contains(filtered[i].id),
                    controller: _controllers[filtered[i].id]!,
                    hint: _hintFor(widget.splitType),
                    suffix: _suffixFor(widget.splitType),
                    onTapMember: () => _toggleMember(filtered[i].id),
                    onChanged: (value) {
                      // Percentage two-member auto-balance: if exactly 2 are
                      // included, typing X fills the other with (100 - X).
                      if (widget.splitType == SplitType.percentage &&
                          _local.length == 2 &&
                          _local.contains(filtered[i].id)) {
                        final entered =
                            (double.tryParse(value) ?? 0).clamp(0, 100);
                        final otherId =
                            _local.firstWhere((id) => id != filtered[i].id);
                        final other = _controllers[otherId];
                        if (other != null) {
                          final remaining = 100 - entered;
                          final formatted = remaining == remaining.toInt()
                              ? remaining.toInt().toString()
                              : remaining.toStringAsFixed(1);
                          other.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      }
                      _emitSplits();
                    },
                  ),
                  if (i < filtered.length - 1) _hairline(isDark),
                ],

                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No members match "$q"',
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ),

                _hairline(isDark),
                _Footer(
                  isDark: isDark,
                  splitType: widget.splitType,
                  total: _includedTotal(),
                  totalAmount: widget.totalAmount,
                ),
              ],
            ],
          ),
        ),

        if (widget.splitType == SplitType.exact) ...[
          const SizedBox(height: 8),
          _HintRow(
            isDark: isDark,
            text:
                'Assign each member\'s amount. The sum must equal ₹${widget.totalAmount.toStringAsFixed(2)}.',
          ),
        ] else if (widget.splitType == SplitType.percentage) ...[
          const SizedBox(height: 8),
          _HintRow(
            isDark: isDark,
            text: 'Percentages should add up to 100%.',
          ),
        ] else if (widget.splitType == SplitType.shares) ...[
          const SizedBox(height: 8),
          _HintRow(
            isDark: isDark,
            text:
                'Weight-based — e.g. 1, 1, 2 splits as 25%, 25%, 50%.',
          ),
        ],
      ],
    );
  }

  Widget _hairline(bool isDark) => Container(
        height: 1,
        color: AppColors.divider(isDark).withValues(alpha: 0.6),
      );
}

// --------------------------------------------------------------------------
// Subwidgets
// --------------------------------------------------------------------------

enum _StatusKind { ok, warn }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isDark});
  final ({String label, _StatusKind kind}) status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isOk = status.kind == _StatusKind.ok;
    final accent = isOk ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: AppTextStyles.caption(isDark).copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 16,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              style: AppTextStyles.body2(isDark).copyWith(fontSize: 13),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: 'Search members',
                hintStyle: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (hasValue)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged();
              },
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.isDark,
    required this.member,
    required this.splitType,
    required this.totalAmount,
    required this.value,
    required this.included,
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.onTapMember,
    required this.onChanged,
  });

  final bool isDark;
  final UserModel member;
  final SplitType splitType;
  final double totalAmount;
  final double value;
  final bool included;
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final VoidCallback onTapMember;
  final ValueChanged<String> onChanged;

  String _initials() {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dim = !included;
    String? caption;
    if (included && value > 0) {
      switch (splitType) {
        case SplitType.exact:
          final pct = totalAmount > 0 ? value / totalAmount * 100 : 0;
          caption = '₹${value.toStringAsFixed(2)}  ·  ${pct.toStringAsFixed(0)}%';
          break;
        case SplitType.percentage:
          if (totalAmount > 0) {
            final amount = totalAmount * value / 100;
            caption = '≈ ₹${amount.toStringAsFixed(2)}';
          }
          break;
        case SplitType.shares:
          caption = '${value.toStringAsFixed(0)} share${value == 1 ? '' : 's'}';
          break;
        case SplitType.equal:
          break;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapMember,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox-style toggle (smaller, brand-tinted)
              _Toggle(included: included, isDark: isDark),
              const SizedBox(width: 10),
              // Avatar
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealDark
                      .withValues(alpha: dim ? 0.06 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _initials(),
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: dim
                        ? AppColors.textSecondary(isDark)
                        : AppColors.tealDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + caption
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTextStyles.body1(isDark).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: dim
                            ? AppColors.textSecondary(isDark)
                            : AppColors.textPrimary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Input
              SizedBox(
                width: 96,
                child: _AmountInput(
                  controller: controller,
                  isDark: isDark,
                  enabled: included,
                  prefix: splitType == SplitType.exact ? '₹' : null,
                  suffix: suffix,
                  hint: hint,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.included, required this.isDark});
  final bool included;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: included ? AppColors.tealDark : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: included
              ? AppColors.tealDark
              : AppColors.divider(isDark),
          width: 1.5,
        ),
      ),
      child: included
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _AmountInput extends StatelessWidget {
  const _AmountInput({
    required this.controller,
    required this.isDark,
    required this.enabled,
    required this.prefix,
    required this.suffix,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isDark;
  final bool enabled;
  final String? prefix;
  final String suffix;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: AppTextStyles.body2(isDark).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: enabled
            ? AppColors.textPrimary(isDark)
            : AppColors.textSecondary(isDark),
      ),
      decoration: InputDecoration(
        isDense: true,
        prefixText: prefix,
        suffixText: suffix.isEmpty ? null : suffix,
        prefixStyle: AppTextStyles.body2(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        suffixStyle: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontSize: 11,
        ),
        hintText: hint,
        hintStyle: AppTextStyles.body2(isDark).copyWith(
          color: AppColors.textSecondary(isDark).withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        filled: true,
        fillColor: enabled
            ? AppColors.surface(isDark)
            : AppColors.background(isDark),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.divider(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: AppColors.tealDark, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: AppColors.divider(isDark).withValues(alpha: 0.6)),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isDark,
    required this.splitType,
    required this.total,
    required this.totalAmount,
  });

  final bool isDark;
  final SplitType splitType;
  final double total;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    String label;
    String value;
    switch (splitType) {
      case SplitType.percentage:
        label = 'Assigned';
        value = '${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 1)}% / 100%';
        break;
      case SplitType.shares:
        label = 'Total shares';
        value = '${total.toStringAsFixed(0)} sh';
        break;
      case SplitType.exact:
        label = 'Assigned';
        value =
            '₹${total.toStringAsFixed(2)} / ₹${totalAmount.toStringAsFixed(2)}';
        break;
      case SplitType.equal:
        label = 'Total';
        value = '₹${total.toStringAsFixed(2)}';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body2(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.isDark, required this.text});
  final bool isDark;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.tealDark.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 14,
            color: AppColors.tealDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textPrimary(isDark),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
