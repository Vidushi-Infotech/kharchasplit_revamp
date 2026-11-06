import { query } from '../config/database.js';
import EmailService from './emailService.js';
import { logger } from '../utils/logger.js';

/**
 * Durable email queue.
 *
 * Notification emails are written to `email_outbox` first and sent from
 * there, so an SMTP hiccup never loses a mail and every send is auditable
 * (who got what, when, and why it failed).
 *
 *   enqueue() → row 'pending' → kick() sends it straight away in-process
 *   failure   → back to 'pending' with exponential backoff, up to MAX_ATTEMPTS,
 *               then 'failed'
 *   worker    → every TICK_SECONDS on PM2 instance 0, retries due rows and
 *               rescues rows stuck in 'sending' (process died mid-send)
 *
 * Rows are claimed with FOR UPDATE SKIP LOCKED, so the in-process kick on
 * any instance and the worker on instance 0 never send the same row twice.
 * `dedupe_key` (unique) makes a retried request harmless.
 *
 * Env: EMAIL_OUTBOX_WORKER=false disables the periodic worker.
 */
const MAX_ATTEMPTS = 5;
const BATCH_SIZE = 20;
const TICK_SECONDS = 60;
const STUCK_MINUTES = 10;

export async function enqueue({ userId = null, toEmail, type, subject, text, html, dedupeKey = null }) {
  if (!toEmail || !toEmail.includes('@')) return null;
  const result = await query(
    `INSERT INTO email_outbox (user_id, to_email, type, subject, text_body, html_body, dedupe_key)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (dedupe_key) DO NOTHING
     RETURNING id`,
    [userId, toEmail, type, subject, text, html, dedupeKey],
  );
  if (result.rows.length > 0) kick();
  return result.rows[0]?.id || null;
}

let draining = false;
let rerun = false;

/** Send whatever is due, without blocking the caller. */
export function kick() {
  if (draining) {
    rerun = true;
    return;
  }
  draining = true;
  setImmediate(async () => {
    try {
      do {
        rerun = false;
        while ((await processBatch()) === BATCH_SIZE) { /* keep draining */ }
      } while (rerun);
    } catch (e) {
      logger.error({ err: e }, '[EmailOutbox] drain failed');
    } finally {
      draining = false;
    }
  });
}

/** Claim and send one batch of due rows. Returns how many were claimed. */
export async function processBatch() {
  const claimed = await query(
    `UPDATE email_outbox
        SET status = 'sending', attempts = attempts + 1, locked_at = NOW()
      WHERE id IN (
        SELECT id FROM email_outbox
         WHERE status = 'pending' AND send_after <= NOW()
         ORDER BY created_at
         LIMIT $1
         FOR UPDATE SKIP LOCKED
      )
      RETURNING id, to_email, type, subject, text_body, html_body, attempts`,
    [BATCH_SIZE],
  );

  for (const row of claimed.rows) {
    const res = await EmailService.sendRaw({
      to: row.to_email,
      subject: row.subject,
      text: row.text_body,
      html: row.html_body,
    });
    if (res.success) {
      await query(
        `UPDATE email_outbox
            SET status = 'sent', sent_at = NOW(), message_id = $2, last_error = NULL, locked_at = NULL
          WHERE id = $1`,
        [row.id, res.messageId || null],
      );
      logger.info({ id: row.id, type: row.type, to: row.to_email }, '[EmailOutbox] sent');
    } else {
      const giveUp = row.attempts >= MAX_ATTEMPTS;
      // 2, 4, 8, 16 minutes between attempts.
      const backoffMinutes = 2 ** row.attempts;
      await query(
        `UPDATE email_outbox
            SET status = $2, last_error = $3, locked_at = NULL,
                send_after = NOW() + ($4 || ' minutes')::interval
          WHERE id = $1`,
        [row.id, giveUp ? 'failed' : 'pending', (res.error || 'unknown').slice(0, 1000), String(backoffMinutes)],
      );
      logger.warn(
        { id: row.id, type: row.type, to: row.to_email, attempts: row.attempts, giveUp, error: res.error },
        '[EmailOutbox] send failed',
      );
    }
  }
  return claimed.rows.length;
}

/** Put rows back in the queue if their sender died mid-send. */
async function rescueStuck() {
  await query(
    `UPDATE email_outbox
        SET status = 'pending', locked_at = NULL
      WHERE status = 'sending' AND locked_at < NOW() - ($1 || ' minutes')::interval`,
    [String(STUCK_MINUTES)],
  );
}

/**
 * Start the periodic retry worker. Returns a stop() function.
 */
export function startEmailOutboxWorker() {
  if (process.env.EMAIL_OUTBOX_WORKER === 'false') {
    logger.info('[EmailOutbox] worker disabled via EMAIL_OUTBOX_WORKER=false');
    return () => {};
  }
  // Same rule as emailVerifyReminderJob: only PM2 instance 0 runs timers.
  const instance = process.env.NODE_APP_INSTANCE ?? process.env.pm_id;
  if (instance !== undefined && String(instance) !== '0') {
    logger.info({ instance }, '[EmailOutbox] not instance 0, worker skipped');
    return () => {};
  }
  const tick = async () => {
    try {
      await rescueStuck();
      kick();
    } catch (e) {
      logger.error({ err: e }, '[EmailOutbox] tick failed');
    }
  };
  const handle = setInterval(tick, TICK_SECONDS * 1000);
  handle.unref();
  tick(); // pick up anything left over from before a restart
  logger.info({ tickSeconds: TICK_SECONDS }, '[EmailOutbox] worker armed');
  return () => clearInterval(handle);
}

export default { enqueue, kick, processBatch, startEmailOutboxWorker };
