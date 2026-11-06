import { query } from '../config/database.js';
import GroupService from '../services/groupService.js';
import { NotificationService } from '../services/notificationService.js';
import { logger } from '../utils/logger.js';
import { startDailyJob, envInt } from './scheduler.js';

/**
 * Automatic "time to settle up" reminders.
 *
 * Once a day, every open debt (group, debtor → creditor) is tracked in
 * auto_reminder_state. A debtor is reminded when the debt has been open for
 * at least AGE_DAYS, the last automatic reminder was INTERVAL_DAYS ago or
 * more, and fewer than MAX reminders have gone out for it. When the debt is
 * settled its row is deleted, so a new debt later starts from zero.
 *
 * Skipped: archived groups, amounts below MIN_AMOUNT, and debtors who got a
 * reminder for that group (manual or automatic) in the last MANUAL_GAP_DAYS.
 * Delivery goes through NotificationService (inbox + push + email), so the
 * user's "Settlement reminders" toggle is honoured.
 *
 * Env (all optional):
 *   AUTO_SETTLEMENT_REMINDERS=false   disable
 *   AUTO_REMINDER_HOUR=11             hour of day to run (server time)
 *   AUTO_REMINDER_AGE_DAYS=3          debt must be open this long
 *   AUTO_REMINDER_INTERVAL_DAYS=7     gap between reminders for one debt
 *   AUTO_REMINDER_MAX=3               reminders per debt
 *   AUTO_REMINDER_MIN_AMOUNT=10       ignore smaller debts
 */
const MANUAL_GAP_DAYS = 3;

const config = () => ({
  ageDays: envInt('AUTO_REMINDER_AGE_DAYS', 3, 0, 365),
  intervalDays: envInt('AUTO_REMINDER_INTERVAL_DAYS', 7, 1, 365),
  max: envInt('AUTO_REMINDER_MAX', 3, 1, 50),
  minAmount: envInt('AUTO_REMINDER_MIN_AMOUNT', 10, 0, 1_000_000),
});

/**
 * Sync auto_reminder_state with the current open debts and return the ones
 * due for a reminder. `dryRun` reads without writing.
 */
export async function findDueReminders({ dryRun = false } = {}) {
  const cfg = config();
  const debts = await GroupService.getOpenPairwiseDebts({ minAmount: Math.max(cfg.minAmount, 0.01) });
  const key = (d) => `${d.groupId}:${d.debtorId}:${d.creditorId}`;

  const stateRows = await query(
    `SELECT group_id, debtor_id, creditor_id, first_seen_at, last_sent_at, sent_count
       FROM auto_reminder_state`,
  );
  const state = new Map(stateRows.rows.map((r) => [`${r.group_id}:${r.debtor_id}:${r.creditor_id}`, r]));

  if (!dryRun) {
    const open = new Set(debts.map(key));
    const gone = stateRows.rows.filter((r) => !open.has(`${r.group_id}:${r.debtor_id}:${r.creditor_id}`));
    for (const r of gone) {
      await query(
        'DELETE FROM auto_reminder_state WHERE group_id = $1 AND debtor_id = $2 AND creditor_id = $3',
        [r.group_id, r.debtor_id, r.creditor_id],
      );
    }
    for (const d of debts.filter((x) => !state.has(key(x)))) {
      await query(
        `INSERT INTO auto_reminder_state (group_id, debtor_id, creditor_id)
         VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
        [d.groupId, d.debtorId, d.creditorId],
      );
    }
  }

  const now = Date.now();
  const day = 86_400_000;
  const due = debts.filter((d) => {
    const s = state.get(key(d));
    if (!s) return false; // first sighting today — the age clock starts now
    if (now - new Date(s.first_seen_at).getTime() < cfg.ageDays * day) return false;
    if (s.sent_count >= cfg.max) return false;
    if (s.last_sent_at && now - new Date(s.last_sent_at).getTime() < cfg.intervalDays * day) return false;
    return true;
  });
  if (due.length === 0) return [];

  // Don't pile on someone who was just reminded for this group.
  const recent = await query(
    `SELECT DISTINCT user_id, data->>'groupId' AS group_id
       FROM notifications
      WHERE type = 'SETTLEMENT_REMINDER'
        AND created_at > NOW() - ($1 || ' days')::interval
        AND user_id = ANY($2::uuid[])`,
    [String(MANUAL_GAP_DAYS), [...new Set(due.map((d) => d.debtorId))]],
  );
  const recentlyReminded = new Set(recent.rows.map((r) => `${r.group_id}:${r.user_id}`));
  return due.filter((d) => !recentlyReminded.has(`${d.groupId}:${d.debtorId}`));
}

/** Run once. Returns a summary. */
export async function runSettlementReminders({ dryRun = false } = {}) {
  const due = await findDueReminders({ dryRun });
  const summary = { due: due.length, sent: 0, failed: 0, dryRun };
  if (dryRun) {
    logger.info({ due }, '[settlementReminder] dry run');
    return summary;
  }

  for (const d of due) {
    try {
      await NotificationService.notifySettlementReminder(d.debtorId, {
        groupId: d.groupId,
        groupName: d.groupName,
        amount: d.amount.toFixed(2),
        currencyCode: d.currency,
        fromUserId: d.creditorId,
        fromUserName: d.creditorName,
        auto: true,
      });
      await query(
        `UPDATE auto_reminder_state
            SET last_sent_at = NOW(), sent_count = sent_count + 1
          WHERE group_id = $1 AND debtor_id = $2 AND creditor_id = $3`,
        [d.groupId, d.debtorId, d.creditorId],
      );
      summary.sent++;
    } catch (err) {
      summary.failed++;
      logger.warn({ err, groupId: d.groupId, debtorId: d.debtorId }, '[settlementReminder] send failed');
    }
  }
  logger.info(summary, '[settlementReminder] run complete');
  return summary;
}

export function startSettlementReminderScheduler() {
  return startDailyJob({
    name: 'settlementReminder',
    disableEnv: 'AUTO_SETTLEMENT_REMINDERS',
    hour: envInt('AUTO_REMINDER_HOUR', 11, 0, 23),
    run: () => runSettlementReminders(),
  });
}
