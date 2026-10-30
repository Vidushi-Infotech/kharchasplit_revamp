import { occurrenceDate } from './recurrence.js';

/**
 * Personal bills' schedule. Pure, unit-tested (tests/personalBills.test.js).
 */

/** The due date the bill is waiting on: occurrence paid_count. */
export function nextDue(bill) {
  return occurrenceDate(bill.anchorDate, bill.frequency, bill.paidCount);
}

const DAY = 86_400_000;
const days = (from, to) =>
  Math.round((new Date(`${to}T00:00:00Z`) - new Date(`${from}T00:00:00Z`)) / DAY);

/**
 * 'overdue' (past due), 'due' (within its reminder window, today
 * included) or 'upcoming'; plus how many days until it's due (negative
 * when overdue).
 */
export function billStatus(bill, today) {
  const due = nextDue(bill);
  const daysLeft = days(today, due);
  const status = daysLeft < 0 ? 'overdue' : daysLeft <= bill.remindDays ? 'due' : 'upcoming';
  return { nextDue: due, daysLeft, status };
}

/** Whether today's reminder run should push for this bill. */
export function needsReminder(bill, today) {
  const { nextDue: due, status } = billStatus(bill, today);
  return status !== 'upcoming' && bill.lastRemindedDue !== due;
}
