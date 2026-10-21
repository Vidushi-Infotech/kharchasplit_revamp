/**
 * Validation for the money parts of an expense write: payers, split totals
 * and how the split was entered. All checks are exact, in paise.
 * Throwing helpers raise an Error with `.status = 400` (and a `.code`).
 */
const toPaise = (v) => Math.round(Number(v) * 100);

const fail = (message, code = 'INVALID_EXPENSE') => {
  const err = new Error(message);
  err.status = 400;
  err.code = code;
  return err;
};

/**
 * @param {unknown} raw  [{ userId, amount }, …] from the request body
 * @returns {Array<{userId: string, amount: string}>} amounts as "123.45"
 */
export function parsePayers(raw) {
  if (!Array.isArray(raw) || raw.length === 0) throw fail('payers must be a non-empty list');
  if (raw.length > 50) throw fail('Too many payers');
  const seen = new Set();
  return raw.map((p) => {
    const userId = p?.userId;
    const paise = toPaise(p?.amount);
    if (typeof userId !== 'string' || !userId) throw fail('Each payer needs a userId');
    if (seen.has(userId)) throw fail('A person can only be listed once as a payer');
    if (!Number.isFinite(paise) || paise <= 0) throw fail('Each payer must have paid more than 0');
    seen.add(userId);
    return { userId, amount: (paise / 100).toFixed(2) };
  });
}

/** The payer recorded in expenses.paid_by: largest amount, then lowest id. */
export function largestPayer(payers) {
  return [...payers].sort((a, b) => toPaise(b.amount) - toPaise(a.amount)
    || (a.userId < b.userId ? -1 : 1))[0].userId;
}

/**
 * What was paid must equal the amount, and so must what is owed — to the
 * paisa. (Only enforced for clients that send `payers`; older builds keep
 * the previous, unchecked behaviour.)
 */
export function checkTotals(amount, payers, participants) {
  const total = toPaise(amount);
  const paid = payers.reduce((s, p) => s + toPaise(p.amount), 0);
  if (paid !== total) {
    throw fail(`Payers add up to ${(paid / 100).toFixed(2)}, not ${(total / 100).toFixed(2)}`, 'PAYERS_MISMATCH');
  }
  if (Array.isArray(participants)) {
    const owed = participants.reduce((s, p) => s + toPaise(p?.amount), 0);
    if (owed !== total) {
      throw fail(`Split adds up to ${(owed / 100).toFixed(2)}, not ${(total / 100).toFixed(2)}`, 'SPLIT_MISMATCH');
    }
  }
}

/**
 * split_type + split_meta to store. "By adjustment" is stored as 'exact'
 * (final amounts) so older app builds show and edit it as exact amounts
 * instead of falling back to "equally"; split_meta remembers the mode and
 * the adjustments for newer builds.
 *
 * @returns {{splitType: string|undefined, splitMeta: object|null|undefined}}
 *   splitMeta undefined = leave unchanged (edits without split info)
 */
export function splitInput({ splitType, splitMeta }) {
  if (splitType === 'adjustment' || splitMeta?.mode === 'adjustment') {
    const adj = splitMeta?.adjustments ?? {};
    if (typeof adj !== 'object' || Array.isArray(adj)
      || !Object.values(adj).every((v) => Number.isFinite(Number(v)))) {
      throw fail('splitMeta.adjustments must map userId to an amount');
    }
    const adjustments = Object.fromEntries(
      Object.entries(adj).map(([k, v]) => [k, Number((toPaise(v) / 100).toFixed(2))]),
    );
    return { splitType: 'exact', splitMeta: { mode: 'adjustment', adjustments } };
  }
  // Any other explicit split type clears an old adjustment record.
  return { splitType, splitMeta: splitType ? null : undefined };
}
