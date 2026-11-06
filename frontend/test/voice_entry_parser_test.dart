import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/category_model.dart';
import 'package:kharchasplit/models/wallet_source_model.dart';
import 'package:kharchasplit/modules/personal_expenses/state/voice_entry_parser.dart';

const _accounts = [
  WalletSource(
    id: 'cash',
    name: 'Cash',
    type: WalletSourceType.cash,
    balance: 0,
  ),
  WalletSource(
    id: 'hdfc',
    name: 'HDFC',
    type: WalletSourceType.bank,
    balance: 0,
  ),
  WalletSource(
    id: 'amex',
    name: 'Amex',
    type: WalletSourceType.card,
    balance: 0,
  ),
  WalletSource(
    id: 'pt',
    name: 'Paytm',
    type: WalletSourceType.wallet,
    balance: 0,
  ),
];

VoiceDraft _p(String s) => VoiceEntryParser.parse(s, accounts: _accounts);

void main() {
  test('amount and category, the plain way', () {
    final d = _p('200 rupees petrol');
    expect(d.amount, 200);
    expect(d.isIncome, isFalse);
    expect(d.category, CategoryModel.fuel);
    expect(d.description, 'Petrol');
    expect(d.daysAgo, 0);
    expect(d.accountId, isNull);
  });

  test('symbols, commas and short scales', () {
    expect(_p('₹1,250 groceries').amount, 1250);
    expect(_p('rs. 99 chai').amount, 99);
    expect(_p('1.5k shoes').amount, 1500);
    expect(_p('2 lakh car repair').amount, 200000);
    expect(_p('5 hazaar rent').amount, 5000);
    expect(_p('4.50 coffee').amount, 4.5);
  });

  test('amounts in words', () {
    expect(_p('two hundred fifty for lunch').amount, 250);
    expect(_p('one thousand five hundred rupees medicine').amount, 1500);
    expect(_p('one lakh fifty thousand rupees').amount, 150000);
    expect(_p('dedh sau ka nashta').amount, 150);
    expect(_p('spent on a coffee').amount, isNull);
  });

  test('the number next to rupees wins', () {
    final d = _p('2 pizzas for 600 rupees');
    expect(d.amount, 600);
    expect(d.category, CategoryModel.food);
  });

  test('Hinglish, day and account', () {
    final d = _p('kal 450 ka khana cash se');
    expect(d.amount, 450);
    expect(d.daysAgo, 1);
    expect(d.category, CategoryModel.food);
    expect(d.accountId, 'cash');
    expect(d.description, 'Khana');

    expect(_p('day before yesterday 300 uber').daysAgo, 2);
    expect(_p('parso 300 auto').category, CategoryModel.travel);
    expect(_p('paid 1200 electricity bill from hdfc').accountId, 'hdfc');
    expect(_p('netflix 649 on card').accountId, 'amex');
    expect(_p('recharge 239 via paytm').accountId, 'pt');
    expect(_p('recharge 239 via gpay').accountId, 'pt');
  });

  test('income', () {
    final s = _p('got salary 50000');
    expect(s.isIncome, isTrue);
    expect(s.amount, 50000);
    expect(s.category, CategoryModel.salary);

    final r = _p('received 2000 refund from amazon');
    expect(r.isIncome, isTrue);
    expect(r.category, CategoryModel.refund);

    final f = _p('freelance project 15k credited');
    expect(f.isIncome, isTrue);
    expect(f.category, CategoryModel.freelance);
    expect(f.amount, 15000);
  });

  test('a note is kept when nothing matches a category', () {
    final d = _p('300 rupees for haircut');
    expect(d.category, isNull);
    expect(d.description, 'Haircut');
    expect(_p('').amount, isNull);
  });
}
