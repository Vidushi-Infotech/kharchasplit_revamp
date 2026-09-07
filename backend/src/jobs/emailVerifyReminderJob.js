import { query } from '../config/database.js';
import EmailService from '../services/emailService.js';
import { logger } from '../utils/logger.js';

/**
 * Email-verification reminder.
 *
 * Verification is optional in the app, so we only nudge people who are
 * clearly *using* it: an unverified address AND real activity in the last
 * week (expenses added, settlements, group changes — anything the app logs
 * to `activities` with them as the actor). One mail per user per
 * REMINDER_COOLDOWN_DAYS, capped at MAX_REMINDERS lifetime, so a user who
 * never wants to verify gets at most a handful of emails ever.
 *
 * Scheduling is in-process (no extra dependency): a timer ticks every
 * TICK_MINUTES and the job runs once per calendar day at RUN_HOUR (server
 * local time). Per-user cooldowns make an accidental double run harmless.
 *
 * Env:
 *   EMAIL_VERIFY_REMINDERS=false           disable entirely
 *   EMAIL_VERIFY_REMINDER_HOUR=10          hour of day to run (0-23)
 *   EMAIL_VERIFY_REMINDER_MIN_ACTIVITY=3   activities in the window to qualify
 */
const ACTIVITY_WINDOW_DAYS = 7;
const REMINDER_COOLDOWN_DAYS = 7;
const MAX_REMINDERS = 3;
const TICK_MINUTES = 15;

const minActivity = () => Number(process.env.EMAIL_VERIFY_REMINDER_MIN_ACTIVITY) || 3;
const runHour = () => {
  const h = Number(process.env.EMAIL_VERIFY_REMINDER_HOUR);
  return Number.isInteger(h) && h >= 0 && h <= 23 ? h : 10;
};

/**
 * Users who should get a reminder right now.
 */
export async function findReminderCandidates() {
  // "Activity" = anything the user *did*: expenses they paid for, settlements
  // they initiated, and whatever the app logged to `activities` with them as
  // the actor. Unioned so the nudge still works if one of those signals is
  // missing on a given deployment (e.g. activity logging is best-effort).
  const result = await query(
    `WITH recent AS (
       SELECT paid_by AS user_id, created_at
         FROM expenses
        WHERE deleted_at IS NULL AND created_at > NOW() - ($1 || ' days')::interval
       UNION ALL
       SELECT from_user_id, created_at
         FROM settlements
        WHERE created_at > NOW() - ($1 || ' days')::interval
       UNION ALL
       SELECT user_id, created_at
         FROM activities
        WHERE deleted_at IS NULL AND created_at > NOW() - ($1 || ' days')::interval
     )
     SELECT u.id, u.name, u.email,
            COALESCE(u.email_verify_reminder_count, 0) AS reminder_count,
            COUNT(r.user_id)::int AS recent_activity
       FROM users u
       JOIN recent r ON r.user_id = u.id
      WHERE u.deleted_at IS NULL
        AND u.email IS NOT NULL AND u.email <> ''
        AND u.email_verified_at IS NULL
        AND (u.is_placeholder IS NULL OR u.is_placeholder = FALSE)
        AND (u.email_verify_reminder_at IS NULL
             OR u.email_verify_reminder_at < NOW() - ($2 || ' days')::interval)
        AND COALESCE(u.email_verify_reminder_count, 0) < $3
      GROUP BY u.id
     HAVING COUNT(r.user_id) >= $4
      ORDER BY COUNT(r.user_id) DESC
      LIMIT 500`,
    [String(ACTIVITY_WINDOW_DAYS), String(REMINDER_COOLDOWN_DAYS), MAX_REMINDERS, minActivity()],
  );
  return result.rows;
}

/**
 * Send reminders to everyone who qualifies. Returns a summary.
 * `dryRun` lists candidates without emailing or stamping.
 */
export async function runEmailVerifyReminders({ dryRun = false } = {}) {
  const candidates = await findReminderCandidates();
  const summary = { candidates: candidates.length, sent: 0, failed: 0, dryRun };
  if (dryRun) {
    logger.info(
      { candidates: candidates.map((c) => ({ id: c.id, email: c.email, activity: c.recent_activity })) },
      '[emailVerifyReminder] dry run',
    );
    return summary;
  }

  for (const u of candidates) {
    const res = await EmailService.sendEmailVerifyReminderEmail({
      toEmail: u.email,
      recipientName: u.name,
      activityCount: u.recent_activity,
      windowDays: ACTIVITY_WINDOW_DAYS,
    });
    if (res.success) {
      summary.sent++;
      await query(
        `UPDATE users
            SET email_verify_reminder_at = NOW(),
                email_verify_reminder_count = COALESCE(email_verify_reminder_count, 0) + 1
          WHERE id = $1`,
        [u.id],
      );
    } else {
      summary.failed++;
      logger.warn({ userId: u.id, err: res.error }, '[emailVerifyReminder] send failed');
    }
  }
  logger.info(summary, '[emailVerifyReminder] run complete');
  return summary;
}

let lastRunDate = null; // 'YYYY-MM-DD' of the last run in this process

/**
 * Start the in-process scheduler. Returns a stop() function.
 */
export function startEmailVerifyReminderScheduler() {
  if (process.env.EMAIL_VERIFY_REMINDERS === 'false') {
    logger.info('[emailVerifyReminder] disabled via EMAIL_VERIFY_REMINDERS=false');
    return () => {};
  }
  // PM2 cluster mode (ecosystem.config.cjs: instances 'max') starts one
  // process per CPU. Only instance 0 may run the scheduler, otherwise every
  // worker would send the same reminders on the same day.
  const instance = process.env.NODE_APP_INSTANCE ?? process.env.pm_id;
  if (instance !== undefined && String(instance) !== '0') {
    logger.info({ instance }, '[emailVerifyReminder] not instance 0 — scheduler skipped');
    return () => {};
  }
  const tick = async () => {
    const now = new Date();
    const today = now.toISOString().slice(0, 10);
    if (now.getHours() < runHour() || lastRunDate === today) return;
    lastRunDate = today;
    try {
      await runEmailVerifyReminders();
    } catch (e) {
      logger.error({ err: e }, '[emailVerifyReminder] run crashed');
    }
  };
  const handle = setInterval(tick, TICK_MINUTES * 60_000);
  handle.unref(); // never keep an otherwise-idle process alive
  logger.info(
    { runHour: runHour(), minActivity: minActivity(), tickMinutes: TICK_MINUTES },
    '[emailVerifyReminder] scheduler armed',
  );
  return () => clearInterval(handle);
}
