import { logger } from '../utils/logger.js';

const TICK_MINUTES = 15;

/**
 * Minimal in-process scheduler for once-a-day / once-a-week jobs, same
 * approach as emailVerifyReminderJob: a timer ticks every TICK_MINUTES and
 * runs the job once per calendar day at `hour` (India time, IST),
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
    logger.info({ instance }, `[${name}] not instance 0, scheduler skipped`);
    return () => {};
  }

  let lastRunDate = null;
  const tick = async () => {
    // India time whatever the server's zone: the hour, the date and the
    // weekday all have to be read in the same zone (a UTC box used to mix
    // the UTC date with its local hour).
    const { date: today, hour: nowHour, weekday: nowDay } = istNow();
    if (nowHour < hour || lastRunDate === today) return;
    if (weekday !== undefined && nowDay !== weekday) return;
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

/** The date ('YYYY-MM-DD'), hour (0-23) and weekday (0 = Sunday) in IST. */
export function istNow(now = new Date()) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', hourCycle: 'h23', weekday: 'short',
    }).formatToParts(now).map((p) => [p.type, p.value]),
  );
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    hour: Number(parts.hour),
    weekday: days.indexOf(parts.weekday),
  };
}

/** Read an integer env var within [min, max], else the fallback. */
export function envInt(key, fallback, min = 0, max = Number.MAX_SAFE_INTEGER) {
  const n = Number(process.env[key]);
  return Number.isInteger(n) && n >= min && n <= max ? n : fallback;
}
