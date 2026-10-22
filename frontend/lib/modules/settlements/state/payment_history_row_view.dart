import 'package:intl/intl.dart';

import '../../../components/list/balance_tone.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_format.dart';
import '../../../models/settlement_model.dart';
import '../../groups/state/group_ledger.dart';
import 'payment_method_format.dart';

/// How one payment on the Payments page reads for the viewer.
class PaymentHistoryRowView {
  const PaymentHistoryRowView({
    required this.title,
    required this.when,
    required this.status,
    required this.statusKind,
    required this.note,
    required this.amount,
    required this.tone,
    required this.canMarkNotReceived,
  });

  /// "Test F. paid you ₹200.00" / "You paid Test F. ₹200.00".
  final String title;

  /// "19 Oct 2026, 9:34 AM · Cash" (method only when recorded).
  final String when;

  /// "Waiting for confirmation" / "Marked as not received" / "Confirmed".
  final String status;
  final PaymentStatusKind statusKind;

  /// Free text such as "Written off — Test Four removed by admin".
  final String? note;

  /// Formatted amount for the trailing column.
  final String amount;

  /// owed (green) for money you received, owe (orange) for money you
  /// paid; settled (gray) while the payment doesn't count yet.
  final BalanceTone tone;

  /// A confirmed payment made to you can still be marked "Not received".
  final bool canMarkNotReceived;
}

enum PaymentStatusKind { pending, failed, confirmed }

/// [otherName] is the resolved full name of the other person, used when the
/// payment itself carries no name (left the group, invited, …).
PaymentHistoryRowView paymentHistoryRowView(
  SettlementModel s, {
  required String? myId,
  required String otherName,
}) {
  final iPaid = s.fromUser.id == myId;
  final amount = CurrencyFormatter.format(s.amount, currency: s.currency);
  final stored = iPaid ? s.toUser.name : s.fromUser.name;
  final usable = stored.trim().isNotEmpty && stored.trim() != 'Unknown';
  // Same wording as the group list; only fall back to the resolved name
  // when the payment has none of its own.
  final title = usable
      ? paymentRowTitle(s, myId)
      : iPaid
      ? AppStrings.youPaidNameAmount(NameFormat.short(otherName), amount)
      : AppStrings.namePaidYou(NameFormat.short(otherName), amount);
  final note = s.note?.trim();
  return PaymentHistoryRowView(
    title: title,
    when: withPaymentMethod(
      DateFormat('d MMM yyyy, h:mm a').format(s.date.toLocal()),
      s.method,
    ),
    status: paymentRowStatus(s) ?? AppStrings.historyPaymentConfirmed,
    statusKind: switch (s.status) {
      SettlementStatus.pending => PaymentStatusKind.pending,
      SettlementStatus.failed => PaymentStatusKind.failed,
      SettlementStatus.completed => PaymentStatusKind.confirmed,
    },
    note: note == null || note.isEmpty ? null : note,
    amount: amount,
    tone: s.status != SettlementStatus.completed
        ? BalanceTone.settled
        : iPaid
        ? BalanceTone.owe
        : BalanceTone.owed,
    canMarkNotReceived: !iPaid && s.status == SettlementStatus.completed,
  );
}

/// One entry of the Payments list: a month header or a payment.
sealed class PaymentHistoryItem {
  const PaymentHistoryItem();
}

class PaymentMonthItem extends PaymentHistoryItem {
  const PaymentMonthItem(this.title);

  /// "October 2026".
  final String title;
}

class PaymentRowItem extends PaymentHistoryItem {
  const PaymentRowItem(this.settlement, {required this.lastInMonth});
  final SettlementModel settlement;

  /// No divider under the last row of a month (the header follows).
  final bool lastInMonth;
}

/// [payments] newest first → month headers with their payments.
List<PaymentHistoryItem> groupPaymentsByMonth(List<SettlementModel> payments) {
  final out = <PaymentHistoryItem>[];
  String? month;
  for (var i = 0; i < payments.length; i++) {
    final s = payments[i];
    final title = DateFormat('MMMM yyyy').format(s.date.toLocal());
    if (title != month) {
      out.add(PaymentMonthItem(title));
      month = title;
    }
    final next = i + 1 < payments.length ? payments[i + 1] : null;
    final last =
        next == null ||
        DateFormat('MMMM yyyy').format(next.date.toLocal()) != title;
    out.add(PaymentRowItem(s, lastInMonth: last));
  }
  return out;
}
