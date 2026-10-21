import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/data/export/export_repository.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/groups/state/export_statement_data.dart';
import 'package:kharchasplit/modules/groups/state/export_statement_pdf.dart';
import 'package:kharchasplit/modules/groups/state/group_detail_provider.dart';
import 'package:kharchasplit/modules/groups/state/group_totals_calculator.dart';
import 'package:kharchasplit/modules/groups/widgets/export_group_menu.dart';

UserModel _user(String id) => UserModel(
  id: id,
  name: id.toUpperCase(),
  email: '',
  phone: '',
  createdAt: DateTime(2026),
);

ExpenseModel _expense(
  String id,
  DateTime date, {
  required Map<String, double> payers,
  required Map<String, double> splits,
  String? syncState,
}) => ExpenseModel(
  id: id,
  title: 'Expense $id',
  amount: payers.values.fold(0, (s, v) => s + v),
  category: CategoryModel.other,
  paidBy: _user(payers.keys.first),
  payers: [
    for (final p in payers.entries)
      ExpensePayer(userId: p.key, name: p.key.toUpperCase(), amount: p.value),
  ],
  splits: [
    for (final s in splits.entries)
      SplitModel(
        userId: s.key,
        userName: s.key.toUpperCase(),
        owedShare: s.value,
      ),
  ],
  date: date,
  createdAt: date,
  syncState: syncState,
);

GroupDetail _detail({
  bool simplify = false,
  List<SimplifiedTransfer> transfers = const [],
  List<SettlementModel> settlements = const [],
}) {
  final members = [_user('a'), _user('b'), _user('c')];
  final expenses = [
    // a paid 90 for all three (30 each).
    _expense(
      '1',
      DateTime(2026, 9, 10),
      payers: {'a': 90},
      splits: {'a': 30, 'b': 30, 'c': 30},
    ),
    // b and c paid 30 each, split between b and c.
    _expense(
      '2',
      DateTime(2026, 10, 2),
      payers: {'b': 30, 'c': 30},
      splits: {'b': 30, 'c': 30},
    ),
    _expense(
      '3',
      DateTime(2026, 10, 3),
      payers: {'c': 500},
      splits: {'a': 500},
      syncState: 'pending',
    ),
  ];
  return GroupDetail(
    group: GroupModel(
      id: 'g',
      name: 'Goa Trip',
      coverEmoji: '',
      members: members,
      currency: 'INR',
      createdAt: DateTime(2026),
      simplifyDebts: simplify,
      simplifiedTransfers: transfers,
    ),
    members: members,
    expenses: expenses,
    settlements: settlements,
    totalExpense: 0,
  );
}

void main() {
  final now = DateTime(2026, 10, 21);

  test('all-time statement: nets, raw pairwise debts, pending left out', () {
    final s = buildGroupStatement(
      detail: _detail(
        settlements: [
          SettlementModel(
            id: 's',
            fromUser: _user('b'),
            toUser: _user('a'),
            amount: 10,
            date: DateTime(2026, 10, 5),
            createdAt: DateTime(2026, 10, 5),
          ),
        ],
      ),
      period: TotalsPeriod.allTime,
      periodLabel: 'All time',
      now: now,
    );
    expect(s.expenses.map((e) => e.description), ['Expense 1', 'Expense 2']);
    expect(s.totalSpending, 150);
    expect(s.pendingExcluded, 1);
    expect(s.currencyCode, 'INR');
    final net = {for (final b in s.balances) b.name: b.net};
    expect(net['A'], closeTo(50, 1e-9)); // 90 − 30 − 10 received
    expect(net['B'], closeTo(-20, 1e-9)); // 30 − 60 + 10 sent
    expect(net['C'], closeTo(-30, 1e-9));
    expect(s.balances.first.name, 'A'); // largest credit first
    final debts = {for (final d in s.debts) '${d.from}>${d.to}': d.amount};
    expect(debts, {'C>A': closeTo(30, 1e-9), 'B>A': closeTo(20, 1e-9)});
    // Debts and nets agree.
    expect(s.debts.fold<double>(0, (t, d) => t + d.amount), closeTo(50, 1e-9));
  });

  test('simplified group: who-owes-whom is the server plan', () {
    final s = buildGroupStatement(
      detail: _detail(
        simplify: true,
        transfers: const [
          SimplifiedTransfer(fromUserId: 'c', toUserId: 'a', amount: 30),
          SimplifiedTransfer(fromUserId: 'b', toUserId: 'a', amount: 30),
        ],
      ),
      period: TotalsPeriod.allTime,
      periodLabel: 'All time',
      now: now,
    );
    expect(s.simplified, isTrue);
    expect(
      s.debts.map((d) => '${d.from}>${d.to}'),
      containsAll(['C>A', 'B>A']),
    );
  });

  test('period filters the expense list, not the balances', () {
    final s = buildGroupStatement(
      detail: _detail(),
      period: TotalsPeriod.thisMonth,
      periodLabel: 'This month',
      now: now,
    );
    expect(s.expenses.map((e) => e.description), ['Expense 2']);
    expect(s.expenses.single.paidBy, 'B, C');
    expect(s.totalSpending, 60);
    expect(s.balances.firstWhere((b) => b.name == 'A').net, closeTo(60, 1e-9));
  });

  test('renders a PDF', () async {
    final s = buildGroupStatement(
      detail: _detail(),
      period: TotalsPeriod.allTime,
      periodLabel: 'All time',
      now: now,
    );
    final bytes = await renderGroupStatementPdf(s);
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('renders ₹ and Hindi names with the bundled Noto fonts', () async {
    ByteData font(String name) =>
        ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());
    final s = buildGroupStatement(
      detail: _detail(),
      period: TotalsPeriod.allTime,
      periodLabel: 'All time',
      now: now,
    );
    final bytes = await renderGroupStatementPdf(
      s,
      fonts: StatementFonts(
        regular: font('NotoSans-Regular.ttf'),
        bold: font('NotoSans-Bold.ttf'),
        devanagari: font('NotoSansDevanagari-Regular.ttf'),
      ),
    );
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    // Noto is embedded as a TrueType font (the built-in-font PDF has none).
    final raw = latin1.decode(bytes);
    expect(raw, contains('/FontFile2'));
    expect(raw, contains('NotoSans'));
  });

  test('pdf-safe text and file names', () {
    expect(statementPdfSafe('Café ₹ राम'), 'Café ? ???');
    expect(
      statementFileName('Goa Trip 2026!', now),
      'kharchasplit_Goa_Trip_2026_statement_2026-10-21.pdf',
    );
    expect(
      statementFileName('राम', now),
      'kharchasplit_group_statement_2026-10-21.pdf',
    );
    expect(statementCurrencyCode('₹'), 'INR');
  });

  test('Content-Disposition file names', () {
    expect(
      filenameFromDisposition(
        'attachment; filename="kharchasplit_x_2026.csv"',
        fallback: 'f.csv',
      ),
      'kharchasplit_x_2026.csv',
    );
    expect(filenameFromDisposition(null, fallback: 'f.csv'), 'f.csv');
    expect(
      filenameFromDisposition(
        'attachment; filename="../../etc/passwd"',
        fallback: 'f.csv',
      ),
      'f.csv',
    );
    expect(
      filenameFromDisposition(
        'attachment; filename="a/b.csv"',
        fallback: 'f.csv',
      ),
      'a_b.csv',
    );
  });
}
