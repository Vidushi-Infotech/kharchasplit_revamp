/**
 * Converting an expense entered in another currency into the group's
 * currency, exactly in paise: the total is rounded once, and the parts
 * (payers or split shares) are distributed with the largest-remainder
 * method so they add up to that total to the paisa. Deterministic: ties go
 * to the earlier part.
 */
const toPaise = (v) => Math.round(Number(v) * 100);

/** Converted total in group currency, as a 2-decimal string. */
export function convertTotal(amount, rate) {
  return (Math.round(toPaise(amount) * Number(rate)) / 100).toFixed(2);
}

/**
 * @param {Array<{amount}>} parts  amounts in the original currency
 * @param {number|string} rate     1 original = rate group currency
 * @param {string} total           convertTotal(sum of the original total)
 * @returns {string[]} converted amounts (2 decimals), summing to `total`
 */
export function convertParts(parts, rate, total) {
  const r = Number(rate);
  const exact = parts.map((p) => toPaise(p.amount) * r);
  const floors = exact.map(Math.floor);
  let left = toPaise(total) - floors.reduce((a, b) => a + b, 0);
  const order = exact
    .map((v, i) => ({ i, frac: v - Math.floor(v) }))
    .sort((a, b) => b.frac - a.frac || a.i - b.i);
  const out = [...floors];
  // `left` can be negative only through rounding the total down; then
  // take from the smallest fractions instead.
  for (let k = 0; left > 0; k = (k + 1) % order.length, left -= 1) out[order[k].i] += 1;
  for (let k = order.length - 1; left < 0; k = (k - 1 + order.length) % order.length, left += 1) out[order[k].i] -= 1;
  return out.map((p) => (p / 100).toFixed(2));
}
