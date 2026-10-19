import { logger } from '../utils/logger.js';

const TICK_MINUTES = 15;

/**
 * Minimal in-process scheduler for once-a-day / once-a-week jobs, same
 * approach as emailVerifyReminderJob: a timer ticks every TICK_MINUTES and
 * runs the job once per calendar day at `hour` (server local time),
 * optionally only on `weekday` (0 = Sunday … 6 = Saturday).
 *
 * Only PM2 instance 0 runs timers, otherwise every cluster worker would
 * send the same mails. Jobs must still be idempotent (per-row cooldowns /
 * dedupe keys), since a restart can re-run a day's job.
 *
 * @param {Object} o
 * @param {string}   o.name        Log prefix.
 * @param {string}   o.disableEnv  Env var that disables the job when 'false'.
 * @param {number}   o.hour        Hour of day (0-23) to run.
 * @param {number}   [o.weekday]   Only run on this day of the week.
 * @param {Function} o.run         async () => summary
 * @returns {Function} stop()
 */
export function startDailyJob({ name, disableEnv, hour, weekday, run }) {
  if (process.env[disableEnv] === 'false') {
    logger.info(`[${name}] disabled via ${disableEnv}=false`);
    return () => {};
  }
  const instance = process.env.NODE_APP_INSTANCE ?? process.env.pm_id;
  if (instance !== undefined && String(instance) !== '0') {
    logger.info({ instance }, `[${name}] not instance 0 — scheduler skipped`);
    return () => {};
  }

  let lastRunDate = null;
  const tick = async () => {
    const now = new Date();
    const today = now.toISOString().slice(0, 10);
    if (now.getHours() < hour || lastRunDate === today) return;
    if (weekday !== undefined && now.getDay() !== weekday) return;
    lastRunDate = today;
    try {
      await run();
    } catch (e) {
      logger.error({ err: e }, `[${name}] run crashed`);
    }
  };
  const handle = setInterval(tick, TICK_MINUTES * 60_000);
  handle.unref();
  logger.info({ hour, weekday, tickMinutes: TICK_MINUTES }, `[${name}] scheduler armed`);
  return () => clearInterval(handle);
}

/** Read an integer env var within [min, max], else the fallback. */
export function envInt(key, fallback, min = 0, max = Number.MAX_SAFE_INTEGER) {
  const n = Number(process.env[key]);
  return Number.isInteger(n) && n >= min && n <= max ? n : fallback;
}
