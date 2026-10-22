import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/user_model.dart';
import '../state/group_member_balances.dart';

/// One member on the Balances page: "Test F. owes ₹200.00 in total".
/// Tapping expands the pairwise lines behind it, with Remind… / Settle up
/// on the lines that involve the viewer.
class BalanceMemberRow extends StatefulWidget {
  const BalanceMemberRow({
    super.key,
    required this.balance,
    required this.myId,
    required this.currency,
    required this.pendingOut,
    required this.onRemind,
    required this.onSettle,
  });

  final MemberBalance balance;
  final String? myId;
  final String currency;

  /// What the viewer already has in pending payments to each person, so
  /// Settle up only asks for the rest.
  final Map<String, double> pendingOut;
  final ValueChanged<UserModel> onRemind;
  final void Function(UserModel creditor, double amount) onSettle;

  @override
  State<BalanceMemberRow> createState() => _BalanceMemberRowState();
}

class _BalanceMemberRowState extends State<BalanceMemberRow> {
  // Local UI state only: whether this row's lines are showing.
  bool _expanded = false;

  String _name(UserModel u) {
    if (u.id == widget.myId) return AppStrings.balanceYou;
    return u.name.trim().isEmpty
        ? AppStrings.formerMember
        : NameFormat.short(u.name);
  }

  String _fmt(double v) =>
      CurrencyFormatter.format(v.abs(), currency: widget.currency);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.balance;
    final isMe = b.member.id == widget.myId;
    final tone = b.settled
        ? BalanceTone.settled
        : BalanceTone.fromAmount(b.net);
    final amount = _fmt(b.net);
    final name = _name(b.member);
    final sentence = switch (tone) {
      BalanceTone.owed =>
        isMe
            ? AppStrings.balanceYouGetBackTotal(amount)
            : AppStrings.balanceGetsBackTotal(name, amount),
      BalanceTone.owe =>
        isMe
            ? AppStrings.balanceYouOweTotal(amount)
            : AppStrings.balanceOwesTotal(name, amount),
      _ =>
        isMe
            ? AppStrings.youAreAllSettledUp
            : AppStrings.balanceIsSettled(name),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: b.lines.isNotEmpty,
          expanded: b.lines.isEmpty ? null : _expanded,
          label: sentence,
          excludeSemantics: true,
          child: InkWell(
            onTap: b.lines.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  AvatarWidget(
                    imageUrl: b.member.avatarUrl,
                    name: b.member.name,
                    radius: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _AmountSentence(
                      sentence: sentence,
                      amount: amount,
                      color: tone.color(isDark),
                      bold: true,
                    ),
                  ),
                  if (b.lines.isNotEmpty)
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textSecondary(isDark),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final line in b.lines) _lineTile(context, isDark, line),
        Divider(height: 1, thickness: 0.6, color: AppColors.divider(isDark)),
      ],
    );
  }

  Widget _lineTile(BuildContext context, bool isDark, MemberBalanceLine line) {
    final b = widget.balance;
    final debtor = line.amount > 0 ? b.member : line.other;
    final creditor = line.amount > 0 ? line.other : b.member;
    final amount = _fmt(line.amount);
    final sentence = debtor.id == widget.myId
        ? AppStrings.balanceYouOweTo(amount, _name(creditor))
        : AppStrings.balanceOwesTo(
            _name(debtor),
            amount,
            creditor.id == widget.myId
                ? AppStrings.balanceYouObject
                : _name(creditor),
          );
    final iAmCreditor = creditor.id == widget.myId;
    final iAmDebtor = debtor.id == widget.myId;
    final toSettle = line.amount.abs() - (widget.pendingOut[creditor.id] ?? 0);
    final tone = iAmCreditor
        ? BalanceTone.owed
        : iAmDebtor
        ? BalanceTone.owe
        : BalanceTone.settled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 2, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                imageUrl: line.other.avatarUrl,
                name: line.other.name,
                radius: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountSentence(
                  sentence: sentence,
                  amount: amount,
                  color: tone.color(isDark),
                ),
              ),
            ],
          ),
          if (iAmCreditor || iAmDebtor)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 6),
              child: iAmCreditor
                  ? _LineButton(
                      label: AppStrings.remindEllipsis,
                      onTap: () => widget.onRemind(debtor),
                    )
                  : toSettle > 0.01
                  ? _LineButton(
                      label: AppStrings.settleUp,
                      primary: true,
                      onTap: () => widget.onSettle(creditor, toSettle),
                    )
                  : Text(
                      AppStrings.balancePending,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// A sentence with its amount picked out in the tone color.
class _AmountSentence extends StatelessWidget {
  const _AmountSentence({
    required this.sentence,
    required this.amount,
    required this.color,
    this.bold = false,
  });

  final String sentence;
  final String amount;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        (bold
                ? Theme.of(context).textTheme.bodyLarge
                : Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(color: AppColors.textPrimary(isDark));
    final at = sentence.indexOf(amount);
    if (at < 0) return Text(sentence, style: base?.copyWith(color: color));
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: sentence.substring(0, at)),
          TextSpan(
            text: amount,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: sentence.substring(at + amount.length)),
        ],
      ),
    );
  }
}

class _LineButton extends StatelessWidget {
  const _LineButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: AppColors.owe,
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(),
          )
        : null;
    return primary
        ? FilledButton(onPressed: onTap, style: style, child: Text(label))
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              visualDensity: VisualDensity.compact,
              shape: const StadiumBorder(),
            ),
            child: Text(label),
          );
  }
}
