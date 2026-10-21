import { query } from '../config/database.js';
import { logger } from '../utils/logger.js';
import { convertParts, convertTotal } from '../utils/fxConvert.js';
import { checkTotals, parsePayers } from '../utils/expenseInput.js';
import { todayIST, toDateOnly } from '../utils/recurrence.js';

/**
 * Exchange rates for expenses entered in another currency.
 *
 * Source: frankfurter.app (European Central Bank reference rates, no API
 * key). A date's rate is fetched once and kept in fx_rates; an expense
 * stores the rate it was converted with, so old expenses are never
 * recalculated when rates move. ECB publishes on working days — for a
 * weekend/holiday Frankfurter returns the previous working day's rate,
 * which is what's stored for that date.
 */
const BASE_URL = process.env.FX_API_URL || 'https://api.frankfurter.app';
const TIMEOUT_MS = 5000;

export class FxUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.status = 503;
    this.code = 'FX_UNAVAILABLE';
  }
}

/**
 * 1 `from` = rate `to`, for `date` ('YYYY-MM-DD', not in the future).
 * @returns {Promise<{rate: number, date: string}>} date = the date the
 *   rate is for (the requested one)
 * @throws FxUnavailableError (currency not supported, service down)
 */
export async function getRate(from, to, date) {
  if (from === to) return { rate: 1, date };
  const cached = await query(
    'SELECT rate FROM fx_rates WHERE rate_date = $1 AND base = $2 AND quote = $3',
    [date, from, to],
  );
  if (cached.rows[0]) return { rate: Number(cached.rows[0].rate), date };

  let body;
  try {
    const res = await fetch(`${BASE_URL}/${date}?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`, {
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (res.status === 404 || res.status === 422) {
      throw new FxUnavailableError(`No exchange rate for ${from} → ${to}`);
    }
    if (!res.ok) throw new FxUnavailableError('Exchange rates are unavailable right now');
    body = await res.json();
  } catch (e) {
    if (e instanceof FxUnavailableError) throw e;
    logger.warn({ err: e.message, from, to, date }, '[fx] fetch failed');
    throw new FxUnavailableError('Exchange rates are unavailable right now');
  }
  const rate = Number(body?.rates?.[to]);
  if (!Number.isFinite(rate) || rate <= 0) {
    throw new FxUnavailableError(`No exchange rate for ${from} → ${to}`);
  }
  await query(
    `INSERT INTO fx_rates (rate_date, base, quote, rate) VALUES ($1, $2, $3, $4)
     ON CONFLICT DO NOTHING`,
    [date, from, to, rate],
  );
  return { rate, date };
}

/**
 * An expense create/edit body entered in another currency
 * (`originalCurrency` ≠ the group's), converted to the group's currency:
 * amount, payers and split amounts become group-currency amounts that add
 * up exactly; `fx` is what to store (original amount + currency, the rate
 * and its date). `fxRate` in the body overrides the looked-up rate (the
 * app offers it when rates are unavailable). Bodies without
 * originalCurrency come back unchanged.
 * @returns {Promise<{body, fx: object|undefined}>}
 */
export async function prepareFx(body, groupCurrency) {
  const orig = body?.originalCurrency;
  if (!orig || !groupCurrency || orig === groupCurrency) return { body, fx: undefined };
  const bad = (msg) => Object.assign(new Error(msg), { status: 400, code: 'INVALID_CURRENCY' });
  if (!/^[A-Z]{3}$/.test(orig)) throw bad('originalCurrency must be a 3-letter currency code');
  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount <= 0) throw bad('amount must be more than 0');

  // Rates exist only up to today; a future-dated expense uses today's.
  const day = toDateOnly(body.expenseDate);
  const today = todayIST();
  const date = day > today ? today : day;
  const rate = body.fxRate != null
    ? Number(body.fxRate)
    : (await getRate(orig, groupCurrency, date)).rate;
  if (!Number.isFinite(rate) || rate <= 0) throw bad('fxRate must be more than 0');

  // Check the entered amounts add up in the currency they were entered in
  // (converting forces the parts to the converted total and would hide a
  // wrong split).
  checkTotals(amount, body.payers !== undefined ? parsePayers(body.payers)
    : [{ userId: body.paidById, amount }], body.participants);

  const total = convertTotal(amount, rate);
  const convert = (parts) => {
    if (!Array.isArray(parts)) return parts;
    const out = convertParts(parts.map((p) => ({ amount: p?.amount ?? 0 })), rate, total);
    return parts.map((p, i) => ({ ...p, amount: Number(out[i]) }));
  };
  return {
    body: {
      ...body,
      amount: Number(total),
      currency: groupCurrency,
      participants: convert(body.participants),
      payers: body.payers !== undefined
        ? convert(body.payers)
        : (body.paidById ? [{ userId: body.paidById, amount: Number(total) }] : undefined),
    },
    fx: {
      originalAmount: amount.toFixed(2),
      originalCurrency: orig,
      fxRate: rate,
      fxDate: date,
    },
  };
}
