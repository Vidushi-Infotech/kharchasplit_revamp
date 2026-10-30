import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildPersonalSummary, shiftMonth, isMonthString } from '../src/utils/personalSummary.js';

test('months shift across years', () => {
  assert.equal(shiftMonth('2026-01', -1), '2025-12');
  assert.equal(shiftMonth('2026-10', -5), '2026-05');
  assert.equal(shiftMonth('2026-12', 1), '2027-01');
  assert.ok(isMonthString('2026-10'));
  assert.ok(!isMonthString('2026-13'));
  assert.ok(!isMonthString('2026-1'));
});

test('summary of a month against the one before', () => {
  const s = buildPersonalSummary([
    { kind: 'expense', category: 'food', day: '2026-10-01', total: '100.10' },
    { kind: 'expense', category: 'food', day: '2026-10-01', total: '50' },
    { kind: 'expense', category: 'fuel', day: '2026-10-31', total: '500' },
    { kind: 'income', category: 'salary', day: '2026-10-01', total: '40000' },
    { kind: 'expense', category: 'food', day: '2026-09-15', total: '300' },
    { kind: 'expense', category: 'travel', day: '2026-09-02', total: '80' },
    { kind: 'income', category: 'salary', day: '2026-09-01', total: '39000' },
    { kind: 'expense', category: 'food', day: '2026-05-03', total: '7' },
    { kind: 'expense', category: 'food', day: '2026-04-30', total: '999' },
    { kind: 'expense', category: null, day: '2026-10-02', total: '1' },
  ], '2026-10');

  assert.equal(s.spent, 651.1);
  assert.equal(s.income, 40000);
  assert.equal(s.previousSpent, 380);
  assert.equal(s.previousIncome, 39000);
  assert.deepEqual(s.categories, [
    { category: 'fuel', amount: 500, previousAmount: 0 },
    { category: 'food', amount: 150.1, previousAmount: 300 },
    { category: 'other', amount: 1, previousAmount: 0 },
    { category: 'travel', amount: 0, previousAmount: 80 },
  ]);
  assert.deepEqual(s.incomeCategories, [{ category: 'salary', amount: 40000 }]);
  assert.equal(s.daily.length, 31);
  assert.deepEqual(s.daily[0], { day: '2026-10-01', spent: 150.1, income: 40000 });
  assert.equal(s.daily[30].spent, 500);
  assert.deepEqual(s.trend.map((t) => t.month), ['2026-05', '2026-06', '2026-07', '2026-08', '2026-09', '2026-10']);
  assert.equal(s.trend[0].spent, 7); // April is outside the window
  assert.equal(s.trend[5].spent, 651.1);
});

test('an empty month', () => {
  const s = buildPersonalSummary([], '2026-02');
  assert.equal(s.daily.length, 28);
  assert.equal(s.spent, 0);
  assert.deepEqual(s.categories, []);
});
