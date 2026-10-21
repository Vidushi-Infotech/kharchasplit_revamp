import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parsePayers, largestPayer, checkTotals, splitInput } from '../src/utils/expenseInput.js';

test('payers are normalised to 2 decimals and validated', () => {
  assert.deepEqual(parsePayers([{ userId: 'a', amount: 60.005 }, { userId: 'b', amount: '40' }]),
    [{ userId: 'a', amount: '60.01' }, { userId: 'b', amount: '40.00' }]);
  for (const bad of [[], null, [{ userId: 'a', amount: 0 }], [{ amount: 5 }],
    [{ userId: 'a', amount: 5 }, { userId: 'a', amount: 5 }]]) {
    assert.throws(() => parsePayers(bad), (e) => e.status === 400);
  }
});

test('largest payer wins, ties go to the lowest id', () => {
  assert.equal(largestPayer([{ userId: 'b', amount: '50.00' }, { userId: 'a', amount: '50.00' }]), 'a');
  assert.equal(largestPayer([{ userId: 'a', amount: '10.00' }, { userId: 'b', amount: '90.00' }]), 'b');
});

test('totals must match to the paisa', () => {
  const payers = [{ userId: 'a', amount: '66.67' }, { userId: 'b', amount: '33.33' }];
  checkTotals(100, payers, [{ amount: 33.34 }, { amount: 33.33 }, { amount: 33.33 }]);
  assert.throws(() => checkTotals(100.01, payers, []), (e) => e.code === 'PAYERS_MISMATCH');
  assert.throws(() => checkTotals(100, payers, [{ amount: 50 }, { amount: 49.99 }]), (e) => e.code === 'SPLIT_MISMATCH');
});

test('adjustment is stored as exact with its meta; other types clear it', () => {
  assert.deepEqual(splitInput({ splitType: 'adjustment', splitMeta: { adjustments: { a: 150, b: '-20.5' } } }),
    { splitType: 'exact', splitMeta: { mode: 'adjustment', adjustments: { a: 150, b: -20.5 } } });
  assert.deepEqual(splitInput({ splitType: 'equal' }), { splitType: 'equal', splitMeta: null });
  assert.deepEqual(splitInput({}), { splitType: undefined, splitMeta: undefined });
  assert.throws(() => splitInput({ splitType: 'adjustment', splitMeta: { adjustments: { a: 'x' } } }), (e) => e.status === 400);
});
