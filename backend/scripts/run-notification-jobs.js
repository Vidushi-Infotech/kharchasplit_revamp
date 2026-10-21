/**
 * Run a scheduled notification job by hand (normally they run in-process
 * on PM2 instance 0 — see src/jobs/).
 *
 * Usage:
 *   node scripts/run-notification-jobs.js --job=reminders [--dry-run]
 *   node scripts/run-notification-jobs.js --job=weekly    [--dry-run]
 *   node scripts/run-notification-jobs.js --job=recurring   (no dry run)
 *
 * --dry-run logs who would be notified without sending or writing state.
 * Emails queued by a real run are sent by this process before it exits.
 */
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import dotenv from 'dotenv';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: resolve(__dirname, '../.env') });

const args = Object.fromEntries(
  process.argv.slice(2).filter((a) => a.startsWith('--')).map((a) => {
    const [k, ...v] = a.slice(2).split('=');
    return [k, v.join('=') || 'true'];
  }),
);
const dryRun = args['dry-run'] === 'true';

const { runSettlementReminders } = await import('../src/jobs/settlementReminderJob.js');
const { runWeeklySummaries } = await import('../src/jobs/weeklySummaryJob.js');
const { runRecurringExpenses } = await import('../src/jobs/recurringExpenseJob.js');
const { processBatch } = await import('../src/services/emailOutbox.js');

const jobs = { reminders: runSettlementReminders, weekly: runWeeklySummaries, recurring: runRecurringExpenses };
const run = jobs[args.job];
if (!run || (args.job === 'recurring' && dryRun)) {
  console.error('Usage: node scripts/run-notification-jobs.js --job=reminders|weekly [--dry-run] | --job=recurring');
  process.exit(1);
}

const summary = await run({ dryRun });
if (!dryRun) {
  // Flush queued emails before exiting (the in-process kick may not finish).
  while ((await processBatch()) > 0) { /* drain */ }
}
console.log(JSON.stringify(summary));
process.exit(0);
