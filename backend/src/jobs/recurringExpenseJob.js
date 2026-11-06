import { startDailyJob, envInt } from './scheduler.js';
import { runDue } from '../services/recurringService.js';
import { logger } from '../utils/logger.js';

/**
 * Creates due recurring expenses once a day (services/recurringService.js).
 * PM2 instance 0 only; runDue() is idempotent anyway, so a restart or a
 * manual run (node run-recurring-expenses.js) can't create duplicates.
 *
 * Env: RECURRING_EXPENSES=false disables it; RECURRING_HOUR (server local
 * time, default 6) is when it runs.
 */
export async function runRecurringExpenses() {
  const summary = await runDue();
  logger.info(summary, '[recurring] run finished');
  return summary;
}

export function startRecurringExpenseScheduler() {
  return startDailyJob({
    name: 'recurringExpenses',
    disableEnv: 'RECURRING_EXPENSES',
    hour: envInt('RECURRING_HOUR', 6, 0, 23),
    run: runRecurringExpenses,
  });
}
