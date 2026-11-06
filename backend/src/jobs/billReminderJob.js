import { startDailyJob, envInt } from './scheduler.js';
import PersonalBill, { toBill } from '../models/PersonalBill.js';
import { NotificationService } from '../services/notificationService.js';
import { isFeatureEnabled } from '../utils/appVersion.js';
import { needsReminder } from '../utils/personalBills.js';
import { todayIST } from '../utils/recurrence.js';
import { logger } from '../utils/logger.js';

/** "today", "tomorrow", "on 2 Nov", "since 28 Oct" (overdue). */
export function dueWhen(nextDue, daysLeft) {
  if (daysLeft === 0) return 'today';
  if (daysLeft === 1) return 'tomorrow';
  const d = new Date(`${nextDue}T00:00:00Z`).toLocaleDateString('en-GB', {
    day: 'numeric', month: 'short', timeZone: 'UTC',
  });
  return daysLeft < 0 ? `since ${d}` : `on ${d}`;
}

/**
 * Pushes "bill due" reminders: each active bill once per due date, from
 * remind_days before it (and on the day it's found overdue, if it was
 * never reminded). Only with the personalBills flag. Idempotent through
 * last_reminded_due, so a restart can't send twice.
 */
export async function runBillReminders(today = todayIST()) {
  if (!isFeatureEnabled('personalBills')) return { skipped: 'flag off' };
  let sent = 0;
  for (const row of await PersonalBill.allActive()) {
    const bill = toBill(row, today);
    if (!needsReminder(bill, today)) continue;
    try {
      await NotificationService.sendToUser(bill.userId, 'PERSONAL_BILL_DUE', {
        billId: bill.id,
        name: bill.name,
        amount: bill.amount.toLocaleString('en-IN'),
        when: dueWhen(bill.nextDue, bill.daysLeft),
        overdue: bill.status === 'overdue' ? 'true' : 'false',
      });
      await PersonalBill.markReminded(bill.id, bill.nextDue);
      sent += 1;
    } catch (e) {
      logger.error({ err: e, billId: bill.id }, '[billReminders] send failed');
    }
  }
  return { sent };
}

/** Env: BILL_REMINDERS=false disables; BILL_REMINDER_HOUR (default 9). */
export function startBillReminderScheduler() {
  return startDailyJob({
    name: 'billReminders',
    disableEnv: 'BILL_REMINDERS',
    hour: envInt('BILL_REMINDER_HOUR', 9, 0, 23),
    run: async () => logger.info(await runBillReminders(), '[billReminders] run finished'),
  });
}
