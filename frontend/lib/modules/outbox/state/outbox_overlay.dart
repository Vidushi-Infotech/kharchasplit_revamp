import '../../../core/outbox/outbox_item.dart';
import '../../../core/outbox/outbox_rules.dart';
import '../../../models/expense_model.dart';
import '../../../models/settlement_model.dart';
import '../../../models/split_model.dart';

/// The group's expenses and payments as the user expects to see them with
/// their unsent changes applied: expenses created offline appear (marked
/// "Pending sync"), edits show their new values, deletes disappear (a
/// failed delete stays, marked "Not synced"), offline payments count.
/// Balances computed from the result include these changes.
({List<ExpenseModel> expenses, List<SettlementModel> settlements}) applyOutbox({
  required String groupId,
  required List<ExpenseModel> expenses,
  required List<SettlementModel> settlements,
  required List<OutboxItem> items,
}) {
  final mine = items.where((i) => i.groupId == groupId).toList();
  if (mine.isEmpty) return (expenses: expenses, settlements: settlements);
  final at = DateTime.now().toIso8601String();
  final outExpenses = [...expenses];
  final outSettlements = [...settlements];

  for (final item in mine) {
    final sync = item.isFailed ? 'failed' : 'pending';
    switch (item.kind) {
      case OutboxKind.createExpense:
        outExpenses.insert(
          0,
          ExpenseModel.fromJson(OutboxRules.expenseJson(item, at: at))
              .copyWith(syncState: sync),
        );
      case OutboxKind.updateExpense:
        final i = outExpenses.indexWhere((e) => e.id == item.expenseId);
        if (i >= 0) outExpenses[i] = _edited(outExpenses[i], item.body, sync);
      case OutboxKind.deleteExpense:
        final i = outExpenses.indexWhere((e) => e.id == item.expenseId);
        if (i >= 0) {
          if (item.isFailed) {
            outExpenses[i] = outExpenses[i].copyWith(syncState: sync);
          } else {
            outExpenses.removeAt(i);
          }
        }
      case OutboxKind.createSettlement:
        final data = OutboxRules.syntheticResponse(item)['data'];
        if (!item.isFailed && data is Map<String, dynamic>) {
          outSettlements.add(SettlementModel.fromJson(data));
        }
    }
  }
  return (expenses: outExpenses, settlements: outSettlements);
}

ExpenseModel _edited(ExpenseModel e, Map<String, dynamic>? b, String sync) {
  if (b == null) return e.copyWith(syncState: sync);
  final participants = b['participants'] as List?;
  final payers = b['payers'] as List?;
  return e.copyWith(
    title: b['description'] as String?,
    amount: (b['amount'] as num?)?.toDouble(),
    notes: b['notes'] as String?,
    splits: participants == null
        ? null
        : [
            for (final p in participants.whereType<Map>())
              SplitModel.fromJson({
                'user_id': p['userId'],
                'amount': p['amount'],
                'name': e.splits
                    .where((s) => s.userId == p['userId'])
                    .map((s) => s.userName)
                    .firstOrNull,
              }),
          ],
    payers: payers == null
        ? null
        : [
            for (final p in payers.whereType<Map>())
              ExpensePayer(
                userId: p['userId'] as String,
                name: e.payers.where((x) => x.userId == p['userId']).map((x) => x.name).firstOrNull ?? '',
                amount: (p['amount'] as num).toDouble(),
              ),
          ],
    syncState: sync,
  );
}
