import { test } from 'node:test';
import assert from 'node:assert/strict';
import { occurrenceDate, firstIndexOnOrAfter, todayIST, isDateString } from '../src/utils/recurrence.js';

test('monthly on the 31st uses the last day of short months and comes back', () => {
  const dates = [0, 1, 2, 3, 4].map((n) => occurrenceDate('2026-01-31', 'monthly', n));
  assert.deepEqual(dates, ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31']);
  assert.equal(occurrenceDate('2027-12-31', 'monthly', 2), '2028-02-29'); // leap year
});

test('weekly, every 2 weeks and yearly (29 Feb)', () => {
  assert.equal(occurrenceDate('2026-10-28', 'weekly', 1), '2026-11-04');
  assert.equal(occurrenceDate('2026-12-24', 'biweekly', 1), '2027-01-07');
  assert.equal(occurrenceDate('2028-02-29', 'yearly', 1), '2029-02-28');
  assert.equal(occurrenceDate('2028-02-29', 'yearly', 4), '2032-02-29');
});

test('first index on or after a date', () => {
  assert.equal(firstIndexOnOrAfter('2026-01-31', 'monthly', '2026-01-01'), 0);
  assert.equal(firstIndexOnOrAfter('2026-01-31', 'monthly', '2026-03-01'), 2);
  assert.equal(firstIndexOnOrAfter('2026-01-31', 'monthly', '2026-02-28'), 1);
  assert.equal(firstIndexOnOrAfter('2026-01-01', 'weekly', '2026-01-08'), 1);
  assert.equal(firstIndexOnOrAfter('2026-01-01', 'weekly', '2026-01-09'), 2);
  for (const f of ['weekly', 'biweekly', 'monthly', 'yearly']) {
    for (let n = 0; n < 60; n += 7) {
      const d = occurrenceDate('2025-08-31', f, n);
      assert.equal(firstIndexOnOrAfter('2025-08-31', f, d), n, `${f} ${n}`);
    }
  }
});

test('today in India and date validation', () => {
  // 20:00 UTC on 31 Oct is already 1 Nov in India (+5:30).
  assert.equal(todayIST(new Date('2026-10-31T20:00:00Z')), '2026-11-01');
  assert.equal(todayIST(new Date('2026-10-31T10:00:00Z')), '2026-10-31');
  assert.ok(isDateString('2026-02-28'));
  assert.ok(!isDateString('2026-02-30'));
  assert.ok(!isDateString('28-02-2026'));
});

test('expense dates from apps become calendar days', async () => {
  const { toDateOnly } = await import('../src/utils/recurrence.js');
  assert.equal(toDateOnly('2026-10-21'), '2026-10-21');
  assert.equal(toDateOnly('2026-10-21T00:00:00.000'), '2026-10-21'); // local, no zone
  assert.equal(toDateOnly('2026-10-20T18:30:00.000Z'), '2026-10-21'); // IST midnight as UTC
  assert.equal(toDateOnly('2026-10-21T09:00:00+05:30'), '2026-10-21');
  assert.match(toDateOnly(undefined), /^\d{4}-\d{2}-\d{2}$/);
});
