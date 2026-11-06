/**
 * Date maths for recurring expenses. Dates are plain 'YYYY-MM-DD' strings
 * (calendar days in India — see todayIST); arithmetic is done on UTC
 * midnight Date objects so no local timezone or DST can shift a day.
 *
 * Every occurrence is computed from the rule's anchor date and its index,
 * never from the previous occurrence, so a monthly rule anchored on the
 * 31st runs on 28/29 Feb and is back on 31 Mar (no drift to the 28th).
 */
export const FREQUENCIES = ['weekly', 'biweekly', 'monthly', 'yearly'];

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isDateString(value) {
  if (typeof value !== 'string' || !DATE_RE.test(value)) return false;
  const d = parse(value);
  // '2026-13-01' parses to an invalid date, which toISOString throws on.
  return !Number.isNaN(d.getTime()) && toDateString(d) === value;
}

const parse = (s) => new Date(`${s}T00:00:00Z`);
const toDateString = (d) => d.toISOString().slice(0, 10);
const daysInMonth = (year, month0) => new Date(Date.UTC(year, month0 + 1, 0)).getUTCDate();

/** Today's date in India, whatever the server timezone. */
export function todayIST(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(now);
}

/** The occurrence with index n (0 = the anchor date itself). */
export function occurrenceDate(anchor, frequency, n) {
  const a = parse(anchor);
  switch (frequency) {
    case 'weekly':
    case 'biweekly': {
      const step = frequency === 'weekly' ? 7 : 14;
      return toDateString(new Date(a.getTime() + n * step * 86_400_000));
    }
    case 'monthly':
    case 'yearly': {
      const months = frequency === 'monthly' ? n : n * 12;
      const total = a.getUTCFullYear() * 12 + a.getUTCMonth() + months;
      const year = Math.floor(total / 12);
      const month0 = total % 12;
      const day = Math.min(a.getUTCDate(), daysInMonth(year, month0));
      return toDateString(new Date(Date.UTC(year, month0, day)));
    }
    default:
      throw new Error(`Unknown frequency: ${frequency}`);
  }
}

/** Smallest index whose occurrence is on or after `date`. */
export function firstIndexOnOrAfter(anchor, frequency, date) {
  if (date <= anchor) return 0;
  // Estimate, then step to the exact index (month lengths vary).
  const days = (parse(date) - parse(anchor)) / 86_400_000;
  const per = { weekly: 7, biweekly: 14, monthly: 30.44, yearly: 365.25 }[frequency];
  let n = Math.max(0, Math.floor(days / per) - 1);
  while (occurrenceDate(anchor, frequency, n) < date) n += 1;
  while (n > 0 && occurrenceDate(anchor, frequency, n - 1) >= date) n -= 1;
  return n;
}

/**
 * The calendar day of an expense date as sent by an app: 'YYYY-MM-DD'
 * as is; a local date-time ("2026-10-21T00:00:00.000") by its date part; an
 * instant with a zone ("…Z" / "+05:30") as that day in India; else today.
 */
export function toDateOnly(value) {
  if (isDateString(value)) return value;
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
    if (/(Z|[+-]\d{2}:?\d{2})$/.test(value)) {
      const d = new Date(value);
      if (!Number.isNaN(d.getTime())) return todayIST(d);
    } else if (isDateString(value.slice(0, 10))) {
      return value.slice(0, 10);
    }
  }
  return todayIST();
}
