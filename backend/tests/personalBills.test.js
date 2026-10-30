import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nextDue, billStatus, needsReminder } from '../src/utils/personalBills.js';

const bill = (o = {}) => ({
  anchorDate: '2026-01-31',
  frequency: 'monthly',
  paidCount: 0,
  remindDays: 2,
  lastRemindedDue: null,
  ...o,
});

test('next due counts up from the anchor without drifting', () => {
  assert.equal(nextDue(bill()), '2026-01-31');
  assert.equal(nextDue(bill({ paidCount: 1 })), '2026-02-28');
  assert.equal(nextDue(bill({ paidCount: 2 })), '2026-03-31');
  assert.equal(nextDue(bill({ frequency: 'weekly', anchorDate: '2026-10-30', paidCount: 2 })), '2026-11-13');
  assert.equal(nextDue(bill({ frequency: 'yearly', anchorDate: '2024-02-29', paidCount: 1 })), '2025-02-28');
});

test('status and reminder window', () => {
  const b = bill({ anchorDate: '2026-11-05' });
  assert.deepEqual(billStatus(b, '2026-10-30'), { nextDue: '2026-11-05', daysLeft: 6, status: 'upcoming' });
  assert.equal(billStatus(b, '2026-11-03').status, 'due');
  assert.equal(billStatus(b, '2026-11-05').status, 'due');
  assert.deepEqual(billStatus(b, '2026-11-07'), { nextDue: '2026-11-05', daysLeft: -2, status: 'overdue' });
  assert.equal(needsReminder(b, '2026-11-02'), false);
  assert.equal(needsReminder(b, '2026-11-03'), true);
  // Once per due date.
  assert.equal(needsReminder({ ...b, lastRemindedDue: '2026-11-05' }, '2026-11-04'), false);
  // Paid: the next one is a month on.
  assert.equal(needsReminder({ ...b, paidCount: 1, lastRemindedDue: '2026-11-05' }, '2026-11-06'), false);
  assert.equal(needsReminder({ ...b, paidCount: 1, lastRemindedDue: '2026-11-05' }, '2026-12-03'), true);
});

test('reminder wording', async () => {
  const { dueWhen } = await import('../src/jobs/billReminderJob.js');
  assert.equal(dueWhen('2026-10-30', 0), 'today');
  assert.equal(dueWhen('2026-10-31', 1), 'tomorrow');
  assert.equal(dueWhen('2026-11-02', 3), 'on 2 Nov');
  assert.equal(dueWhen('2026-10-28', -2), 'since 28 Oct');
});
