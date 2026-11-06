import { query } from '../config/database.js';
import GroupService from '../services/groupService.js';
import { NotificationService } from '../services/notificationService.js';
import { formatMoney } from '../utils/currency.js';
import { logger } from '../utils/logger.js';
import { startDailyJob, envInt } from './scheduler.js';

/**
 * Weekly summary email — opt-in via the "Weekly summary" toggle
 * (notification_prefs.weekly_summary, default off).
 *
 * Runs on WEEKLY_SUMMARY_WEEKDAY at WEEKLY_SUMMARY_HOUR (server time) and
 * covers the previous 7 days: expenses added in the user's groups, their
 * share, settlements paid / received, plus every balance still open.
 * Users with nothing to report are skipped. Each mail is de-duplicated per
 * user per week, so a restart can't send it twice.
 *
 * Env (all optional):
 *   WEEKLY_SUMMARY=false          disable
 *   WEEKLY_SUMMARY_WEEKDAY=1      0 = Sunday … 6 = Saturday (default Monday)
 *   WEEKLY_SUMMARY_HOUR=10
 */
const WINDOW_DAYS = 7;

/** Opted-in users. Email / verification checks happen in NotificationService. */
async function findSubscribers() {
  const result = await query(
    `SELECT u.id
       FROM notification_prefs p
       JOIN users u ON u.id = p.user_id
      WHERE p.weekly_summary = TRUE
        AND p.email_enabled = TRUE
        AND u.deleted_at IS NULL
        AND u.email_verified_at IS NOT NULL`,
  );
  return result.rows.map((r) => r.id);
}

/** Last-7-days activity for one user, grouped by currency. */
async function weekStats(userId) {
  const [expenses, settlements] = await Promise.all([
    query(
      `SELECT g.currency,
              COUNT(DISTINCT e.id)::int AS count,
              COALESCE(SUM(es.amount) FILTER (WHERE es.user_id = $1), 0) AS my_share
         FROM expenses e
         JOIN groups g ON g.id = e.group_id AND g.deleted_at IS NULL
         JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $1 AND gm.deleted_at IS NULL
         LEFT JOIN expense_splits es ON es.expense_id = e.id AND es.deleted_at IS NULL
        WHERE e.deleted_at IS NULL
          AND e.created_at > NOW() - ($2 || ' days')::interval
        GROUP BY g.currency`,
      [userId, String(WINDOW_DAYS)],
    ),
    query(
      `SELECT g.currency,
              COALESCE(SUM(s.amount) FILTER (WHERE s.from_user_id = $1), 0) AS paid,
              COALESCE(SUM(s.amount) FILTER (WHERE s.to_user_id = $1), 0) AS received
         FROM settlements s
         JOIN groups g ON g.id = s.group_id AND g.deleted_at IS NULL
        WHERE s.deleted_at IS NULL AND s.status = 'paid'
          -- Write-offs from member removal aren't real payments.
          AND COALESCE(s.notes, '') NOT LIKE 'Written off%'
          AND (s.from_user_id = $1 OR s.to_user_id = $1)
          AND s.created_at > NOW() - ($2 || ' days')::interval
        GROUP BY g.currency`,
      [userId, String(WINDOW_DAYS)],
    ),
  ]);
  return { expenses: expenses.rows, settlements: settlements.rows };
}

const joinMoney = (rows, field) =>
  rows.filter((r) => Number(r[field]) > 0).map((r) => formatMoney(r[field], r.currency)).join(' + ');

function weekLabel(now = new Date()) {
  const from = new Date(now.getTime() - WINDOW_DAYS * 86_400_000);
  const fmt = (d) => d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', timeZone: 'Asia/Kolkata' });
  return `${fmt(from)} – ${fmt(now)}`;
}

/** Build one user's digest, or null when there's nothing to say. */
export async function buildSummary(userId) {
  const [{ expenses, settlements }, debts] = await Promise.all([
    weekStats(userId),
    GroupService.getOpenPairwiseDebts({ userId, includeArchived: true }),
  ]);

  const expenseCount = expenses.reduce((n, r) => n + r.count, 0);
  const stats = [];
  if (expenseCount > 0) {
    stats.push(['Expenses added in your groups', String(expenseCount)]);
    const share = joinMoney(expenses, 'my_share');
    if (share) stats.push(['Your share of them', share]);
  }
  const paid = joinMoney(settlements, 'paid');
  const received = joinMoney(settlements, 'received');
  if (paid) stats.push(['You settled', paid]);
  if (received) stats.push(['You received', received]);

  const balances = debts
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 10)
    .map((d) => (d.debtorId === userId
      ? [`You owe ${d.creditorName} · ${d.groupName}`, formatMoney(d.amount, d.currency)]
      : [`${d.debtorName} owes you · ${d.groupName}`, formatMoney(d.amount, d.currency)]));

  if (stats.length === 0 && balances.length === 0) return null;
  return { stats, balances };
}

/** Run once. Returns a summary. */
export async function runWeeklySummaries({ dryRun = false } = {}) {
  const userIds = await findSubscribers();
  const label = weekLabel();
  const weekKey = new Date().toISOString().slice(0, 10);
  const summary = { subscribers: userIds.length, sent: 0, skipped: 0, failed: 0, dryRun };

  for (const userId of userIds) {
    try {
      const digest = await buildSummary(userId);
      if (!digest) {
        summary.skipped++;
        continue;
      }
      if (dryRun) {
        logger.info({ userId, digest }, '[weeklySummary] dry run');
        continue;
      }
      await NotificationService.sendToUser(userId, 'WEEKLY_SUMMARY', { weekLabel: label }, {
        dedupeId: `week-${weekKey}`,
        emailContext: { [userId]: digest },
      });
      summary.sent++;
    } catch (err) {
      summary.failed++;
      logger.warn({ err, userId }, '[weeklySummary] failed');
    }
  }
  logger.info(summary, '[weeklySummary] run complete');
  return summary;
}

export function startWeeklySummaryScheduler() {
  return startDailyJob({
    name: 'weeklySummary',
    disableEnv: 'WEEKLY_SUMMARY',
    hour: envInt('WEEKLY_SUMMARY_HOUR', 10, 0, 23),
    weekday: envInt('WEEKLY_SUMMARY_WEEKDAY', 1, 0, 6),
    run: () => runWeeklySummaries(),
  });
}
