import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/modules/settlements/state/settle_button_label.dart';

void main() {
  test('the full amount you owe settles up', () {
    expect(settleButtonLabel(owed: 166.68, amount: 166.68), 'Settle up');
    expect(settleButtonLabel(owed: 166.68, amount: 200), 'Settle up');
  });

  test('a part payment is recorded', () {
    expect(settleButtonLabel(owed: 166.68, amount: 100), 'Record');
    expect(settleButtonLabel(owed: 166.68, amount: null), 'Record');
  });

  test('nothing owed or unknown balance: Record', () {
    expect(settleButtonLabel(owed: null, amount: 50), 'Record');
    expect(settleButtonLabel(owed: 0, amount: 50), 'Record');
    expect(settleButtonLabel(owed: -20, amount: 50), 'Record');
  });
}
